<?php

/*
 * Application mobile Boulfrik : dernière version publiée.
 * - build > build installé : l'application propose la mise à jour (page « Mise à jour disponible ») ;
 * - min_build > build installé : la mise à jour est obligatoire.
 */
return [
    'version' => env('MOBILE_VERSION', '1.0.0'),
    'build' => env('MOBILE_BUILD', 1),
    'min_build' => env('MOBILE_MIN_BUILD', 1),
    'apk_url' => env('MOBILE_APK_URL', rtrim((string) env('APP_URL', ''), '/').'/downloads/boulfrik.apk'),
    'notes' => env('MOBILE_NOTES', ''),
];
