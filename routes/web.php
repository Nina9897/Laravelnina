<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Revisa que la app y la base de datos respondan
Route::get('/health', function () {
    try {
        DB::select('select 1');
        Log::info('Health check OK', ['db' => 'sqlite']);
        return response()->json(['status' => 'ok', 'database' => 'up']);
    } catch (\Throwable $e) {
        Log::error('Health check fallo: ' . $e->getMessage());
        return response()->json(['status' => 'error', 'database' => 'down'], 500);
    }
});

// Hace una consulta a la base de datos y la anota en el log
Route::get('/prueba-log', function () {
    Log::info('Operacion de prueba ejecutada', ['usuarios' => DB::table('users')->count()]);
    return 'Operacion registrada en el log';
});