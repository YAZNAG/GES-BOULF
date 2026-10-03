<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Vente;
use App\Models\Facture;
use Illuminate\Http\Request;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function salesReport(Request $request)
    {
        $range = $request->query('range', 'today');
        $query = Vente::with(['client', 'items.article']);

        switch ($range) {
            case 'yesterday':
                $query->whereDate('date_vente', Carbon::yesterday());
                break;
            case 'week':
                $query->whereBetween('date_vente', [Carbon::now()->startOfWeek(), Carbon::now()->endOfWeek()]);
                break;
            case 'month':
                $query->whereMonth('date_vente', Carbon::now()->month)
                      ->whereYear('date_vente', Carbon::now()->year);
                break;
            case 'today':
            default:
                $query->whereDate('date_vente', Carbon::today());
                break;
        }

        $ventes = $query->get();

        $stats = [
            'total_ventes' => $ventes->sum('montant_total'),
            'nombre_factures' => $ventes->count(),
            'total_encaisse' => $ventes->sum('montant_paye'),
            'total_credit' => $ventes->sum(fn($v) => $v->montant_total - $v->montant_paye),
        ];

        if ($request->query('download') === 'csv') {
            return $this->downloadCsv($ventes, $stats, $range);
        }

        return response()->json([
            'range' => $range,
            'stats' => $stats,
            'ventes' => $ventes
        ]);
    }

    private function downloadCsv($ventes, $stats, $range)
    {
        $filename = "rapport_ventes_{$range}_" . date('Y-m-d') . ".csv";

        return response()->streamDownload(function() use ($ventes, $stats, $range) {
            $handle = fopen('php://output', 'w');

            // Add BOM for Excel UTF-8 support
            fprintf($handle, chr(0xEF).chr(0xBB).chr(0xBF));

            // Header
            fputcsv($handle, ['Rapport des Ventes - ' . ucfirst($range)]);
            fputcsv($handle, ['Date de generation', date('Y-m-d H:i')]);
            fputcsv($handle, []);

            // Stats
            fputcsv($handle, ['Resume des statistiques']);
            fputcsv($handle, ['Total des ventes', number_format($stats['total_ventes'], 2) . ' DH']);
            fputcsv($handle, ['Nombre de factures', $stats['nombre_factures']]);
            fputcsv($handle, ['Total encaisse', number_format($stats['total_encaisse'], 2) . ' DH']);
            fputcsv($handle, ['Total credit (Dettes)', number_format($stats['total_credit'], 2) . ' DH']);
            fputcsv($handle, []);

            // Table Header
            fputcsv($handle, ['ID Vente', 'Date', 'Client', 'Article', 'Quantite', 'Prix Unit.', 'Total Article', 'Total Vente', 'Paye', 'Reste']);

            foreach ($ventes as $vente) {
                $isFirst = true;
                foreach ($vente->items as $ligne) {
                    fputcsv($handle, [
                        $isFirst ? $vente->id : '',
                        $isFirst ? $vente->date_vente : '',
                        $isFirst ? ($vente->client?->nom ?? 'Client de passage') : '',
                        $ligne->article?->nom,
                        $ligne->quantite,
                        $ligne->prix_unitaire,
                        $ligne->quantite * $ligne->prix_unitaire,
                        $isFirst ? $vente->montant_total : '',
                        $isFirst ? $vente->montant_paye : '',
                        $isFirst ? ($vente->montant_total - $vente->montant_paye) : '',
                    ]);
                    $isFirst = false;
                }
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"$filename\"",
        ]);
    }
}
