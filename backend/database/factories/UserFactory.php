<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        $roleId = DB::table('roles')->value('id');

        if (!$roleId) {
            $now = now();
            $roleId = DB::table('roles')->insertGetId([
                'nom' => 'vendeur',
                'description' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        return [
            'role_id' => $roleId,
            'nom' => fake()->lastName(),
            'prenom' => fake()->firstName(),
            'email' => fake()->unique()->safeEmail(),
            'mot_de_passe' => static::$password ??= Hash::make('password'),
            'actif' => true,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => []);
    }
}
