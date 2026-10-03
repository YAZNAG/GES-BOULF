<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CommandeVente;
use App\Models\Vente;
use Carbon\Carbon;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function stats(Request $request)
    {
        $range = (string) $request->query('range', 'week');
        if (!in_array($range, ['today', 'yesterday', 'week', 'month'], true)) {
            $range = 'week';
        }

        $refDate = $this->parseDate($request->query('date')) ?? Carbon::today();

        $periodStart = $refDate->copy()->startOfDay();
        $periodEnd = $refDate->copy()->endOfDay();

        if ($range === 'yesterday') {
            $periodStart = $refDate->copy()->subDay()->startOfDay();
            $periodEnd = $refDate->copy()->subDay()->endOfDay();
        } elseif ($range === 'week') {
            $periodStart = $refDate->copy()->startOfWeek(Carbon::MONDAY)->startOfDay();
            $periodEnd = $refDate->copy()->endOfWeek(Carbon::SUNDAY)->endOfDay();
        } elseif ($range === 'month') {
            $periodStart = $refDate->copy()->startOfMonth()->startOfDay();
            $periodEnd = $refDate->copy()->endOfMonth()->endOfDay();
        }

        $ordersCount = CommandeVente::query()
            ->whereBetween('date_commande', [$periodStart, $periodEnd])
            ->count();

        $revenue = (float) Vente::query()
            ->whereBetween('date_vente', [$periodStart, $periodEnd])
            ->sum('montant_total');

        [$prevStart, $prevEnd] = $this->previousPeriod($range, $periodStart, $periodEnd);
        $prevOrdersCount = CommandeVente::query()
            ->whereBetween('date_commande', [$prevStart, $prevEnd])
            ->count();
        $prevRevenue = (float) Vente::query()
            ->whereBetween('date_vente', [$prevStart, $prevEnd])
            ->sum('montant_total');

        $chart = $this->buildChart($range, $periodStart, $periodEnd);
        $summary = $this->buildSummary($range, $periodStart, $periodEnd, $chart['points']);

        $monthParam = (string) $request->query('month', '');
        $calendarMonth = $this->parseMonth($monthParam) ?? $refDate->copy()->startOfMonth();
        $calendar = $this->buildCalendar($calendarMonth);

        return response()->json([
            'range' => $range,
            'ref_date' => $refDate->toDateString(),
            'period' => [
                'start' => $periodStart->toDateString(),
                'end' => $periodEnd->toDateString(),
            ],
            'metrics' => [
                'orders_count' => $ordersCount,
                'revenue' => $revenue,
                'compare' => [
                    'orders_pct' => $this->pctChange($ordersCount, $prevOrdersCount),
                    'revenue_pct' => $this->pctChange($revenue, $prevRevenue),
                    'prev_orders_count' => $prevOrdersCount,
                    'prev_revenue' => $prevRevenue,
                    'prev_period' => [
                        'start' => $prevStart->toDateString(),
                        'end' => $prevEnd->toDateString(),
                    ],
                ],
            ],
            'chart' => $chart,
            'summary' => $summary,
            'calendar' => $calendar,
        ]);
    }

    private function parseDate($value): ?Carbon
    {
        if (!$value) return null;
        try {
            return Carbon::parse((string) $value);
        } catch (\Throwable) {
            return null;
        }
    }

    private function parseMonth(string $value): ?Carbon
    {
        if ($value === '') return null;
        if (!preg_match('/^\d{4}-\d{2}$/', $value)) return null;
        try {
            return Carbon::createFromFormat('Y-m', $value)->startOfMonth();
        } catch (\Throwable) {
            return null;
        }
    }

    private function previousPeriod(string $range, Carbon $start, Carbon $end): array
    {
        if ($range === 'month') {
            $prev = $start->copy()->subMonthNoOverflow()->startOfMonth()->startOfDay();
            $prevEnd = $prev->copy()->endOfMonth()->endOfDay();
            return [$prev, $prevEnd];
        }

        if ($range === 'week') {
            $prevEnd = $start->copy()->subDay()->endOfDay();
            $prevStart = $prevEnd->copy()->subDays(6)->startOfDay();
            return [$prevStart, $prevEnd];
        }

        $prevStart = $start->copy()->subDay()->startOfDay();
        $prevEnd = $start->copy()->subDay()->endOfDay();
        return [$prevStart, $prevEnd];
    }

    private function pctChange(float|int $current, float|int $previous): float
    {
        $c = (float) $current;
        $p = (float) $previous;
        if ($p == 0.0) {
            return $c == 0.0 ? 0.0 : 100.0;
        }
        return round((($c - $p) / $p) * 100, 2);
    }

    private function buildChart(string $range, Carbon $start, Carbon $end): array
    {
        if ($range === 'month') {
            $monthStart = $start->copy()->startOfMonth()->startOfDay();
            $monthEnd = $start->copy()->endOfMonth()->endOfDay();
            $daysInMonth = (int) $monthStart->daysInMonth;
            $buckets = [
                ['label' => 'S1', 'start' => 1, 'end' => 7],
                ['label' => 'S2', 'start' => 8, 'end' => 14],
                ['label' => 'S3', 'start' => 15, 'end' => 21],
                ['label' => 'S4', 'start' => 22, 'end' => $daysInMonth],
            ];

            $points = [];
            foreach ($buckets as $b) {
                $bucketStart = $monthStart->copy()->day($b['start'])->startOfDay();
                $bucketEnd = $monthStart->copy()->day($b['end'])->endOfDay();
                if ($bucketEnd->greaterThan($monthEnd)) $bucketEnd = $monthEnd->copy();
                $value = CommandeVente::query()
                    ->whereBetween('date_commande', [$bucketStart, $bucketEnd])
                    ->count();
                $points[] = ['day' => $b['label'], 'value' => (int) $value];
            }

            return $this->withBest($points);
        }

        if ($range === 'today' || $range === 'yesterday') {
            $hours = [9, 11, 13, 15, 17, 19];
            $points = [];
            foreach ($hours as $h) {
                $bucketStart = $start->copy()->setTime($h, 0, 0);
                $bucketEnd = $start->copy()->setTime($h, 59, 59)->addHour();
                if ($bucketEnd->greaterThan($end)) $bucketEnd = $end->copy();
                $value = CommandeVente::query()
                    ->whereBetween('date_commande', [$bucketStart, $bucketEnd])
                    ->count();
                $points[] = ['day' => str_pad((string) $h, 2, '0', STR_PAD_LEFT) . 'h', 'value' => (int) $value];
            }

            return $this->withBest($points);
        }

        $labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

        $rows = CommandeVente::query()
            ->selectRaw('DATE(date_commande) as d, COUNT(*) as c')
            ->whereBetween('date_commande', [$start, $end])
            ->groupBy('d')
            ->get()
            ->keyBy('d');

        $weekStart = $start->copy()->startOfWeek(Carbon::MONDAY)->startOfDay();
        $points = [];
        foreach ($labels as $idx => $label) {
            $date = $weekStart->copy()->addDays($idx)->toDateString();
            $value = (int) ($rows->get($date)->c ?? 0);
            $points[] = ['day' => $label, 'value' => $value];
        }

        return $this->withBest($points);
    }

    private function withBest(array $points): array
    {
        $best = null;
        foreach ($points as $p) {
            if (!$best || (int) $p['value'] > (int) $best['value']) $best = $p;
        }
        return [
            'points' => $points,
            'best_day' => $best ? (string) $best['day'] : '—',
            'best_value' => $best ? (int) $best['value'] : 0,
        ];
    }

    private function buildSummary(string $range, Carbon $start, Carbon $end, array $points): array
    {
        // For today/yesterday, we aggregate by hour
        if ($range === 'today' || $range === 'yesterday') {
            $hours = [];
            for ($h = 0; $h < 24; $h++) {
                $bStart = $start->copy()->setTime($h, 0, 0);
                $bEnd = $start->copy()->setTime($h, 59, 59);
                
                $orders = CommandeVente::query()
                    ->whereBetween('date_commande', [$bStart, $bEnd])
                    ->count();
                
                $revenue = Vente::query()
                    ->whereBetween('date_vente', [$bStart, $bEnd])
                    ->sum('montant_total');

                if ($orders > 0) {
                    $hours[] = [
                        'label' => $h . 'h - ' . ($h + 1) . 'h',
                        'orders' => $orders,
                        'revenue' => (float) $revenue,
                    ];
                }
            }
            usort($hours, fn($a, $b) => $b['orders'] <=> $a['orders']);
            $top = array_slice($hours, 0, 4);
            
            return array_map(fn($item, $idx) => [
                'label' => $item['label'],
                'orders' => $item['orders'],
                'revenue' => $item['revenue'],
                'tag' => $idx === 0 ? 'Peak hour' : 'Actif'
            ], $top, array_keys($top));
        }

        // For week/month, we aggregate by day
        $ordersByDate = CommandeVente::query()
            ->selectRaw('DATE(date_commande) as d, COUNT(*) as c')
            ->whereBetween('date_commande', [$start, $end])
            ->groupBy('d')
            ->get()
            ->keyBy('d');

        $revenueByDate = Vente::query()
            ->selectRaw('DATE(date_vente) as d, SUM(montant_total) as s')
            ->whereBetween('date_vente', [$start, $end])
            ->groupBy('d')
            ->get()
            ->keyBy('d');

        $days = [];
        $cursor = $start->copy()->startOfDay();
        while ($cursor->lte($end)) {
            $d = $cursor->toDateString();
            $c = (int) ($ordersByDate->get($d)->c ?? 0);
            if ($c > 0 || $range === 'week') {
                $days[] = [
                    'date' => $d,
                    'orders' => $c,
                    'revenue' => (float) ($revenueByDate->get($d)->s ?? 0),
                ];
            }
            $cursor->addDay();
        }

        usort($days, fn($a, $b) => $b['orders'] <=> $a['orders']);
        $top = array_slice($days, 0, 4);

        return array_map(function($row, $idx) use ($range) {
            $date = Carbon::parse($row['date']);
            $label = ($range === 'month') 
                ? $date->locale('fr')->translatedFormat('d M')
                : $date->locale('fr')->translatedFormat('l');

            return [
                'label' => ucfirst($label),
                'orders' => (int) $row['orders'],
                'revenue' => (float) $row['revenue'],
                'tag' => $idx === 0 ? 'Peak day' : ($idx === 3 ? 'Plus bas' : 'Stable'),
            ];
        }, $top, array_keys($top));
    }

    private function buildCalendar(Carbon $monthStart): array
    {
        $start = $monthStart->copy()->startOfMonth()->startOfDay();
        $end = $monthStart->copy()->endOfMonth()->endOfDay();

        $orders = CommandeVente::query()
            ->selectRaw('DATE(date_commande) as d, COUNT(*) as c')
            ->whereBetween('date_commande', [$start, $end])
            ->groupBy('d')
            ->get()
            ->keyBy('d');

        $revenue = Vente::query()
            ->selectRaw('DATE(date_vente) as d, SUM(montant_total) as s')
            ->whereBetween('date_vente', [$start, $end])
            ->groupBy('d')
            ->get()
            ->keyBy('d');

        $days = [];
        $cursor = $start->copy();
        while ($cursor->lte($end)) {
            $d = $cursor->toDateString();
            $days[] = [
                'date' => $d,
                'orders' => (int) ($orders->get($d)->c ?? 0),
                'revenue' => (float) ($revenue->get($d)->s ?? 0),
            ];
            $cursor->addDay();
        }

        return [
            'month' => $start->format('Y-m'),
            'days' => $days,
        ];
    }
}
