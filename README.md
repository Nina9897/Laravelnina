# CI Pipeline para Laravel

## Objetivo
Automatizar la instalación de dependencias y la ejecución de pruebas de la
aplicación Laravel mediante GitHub Actions.

## Tecnologías
PHP 8.2, Laravel 11.57, Composer, PHPUnit, Git, GitHub y GitHub Actions.

## Requisitos
PHP 8.2 o superior, Composer, Git y acceso al repositorio de GitHub.

## Instalación local
1. `git clone https://github.com/Nina9897/Laravelnina.git`
2. `composer install`
3. Copiar `.env.example` a `.env`
4. `php artisan key:generate`
5. `php artisan migrate` (el proyecto usa SQLite)
6. `php artisan test`

## Integración continua
El workflow `.github/workflows/ci.yml` se ejecuta al enviar cambios a `main` o
al crear un pull request hacia ella. Obtiene el código, configura PHP 8.2,
valida Composer, instala dependencias, prepara el entorno y ejecuta
`php artisan test` con SQLite en memoria. No despliega a producción.

![Estructura y ci.yml](docs/03-estructura-ci.png)

## Pruebas
`tests/Feature/HomePageTest.php` verifica que la ruta `/` responda con éxito
(HTTP 200). Junto con las 2 pruebas de ejemplo de Laravel, el proyecto tiene 3
pruebas, que pasaron en local antes de configurar el CI.

![Pruebas locales](docs/02-pruebas-locales.png)

## Evidencias

**1. Ejecución exitosa**
Commit `276ca8b`, 16/10/2026, 3 pruebas pasadas en 20 s.
[Ver ejecución](https://github.com/Nina9897/Laravelnina/actions/runs/38981060339)
Todos los pasos terminaron en verde: el proyecto se comporta en GitHub igual
que en local.

![Exitosa](docs/04-actions-exitosa.png)

**2. Ejecución fallida (controlada)**
Commit `<hash>`, `<fecha>`. [Ver ejecución](<URL>)
Se cambió `assertSuccessful()` por `assertStatus(404)`. Error en el log:

```
Expected response status code [404] but received 200.
```

La prueba exigía 404, pero la ruta `/` responde 200. Los pasos previos pasaron;
el pipeline falló solo en las pruebas. Solución: restaurar `assertSuccessful()`.

![Fallo local](docs/05-fallo-local.png)
![Fallida](docs/06-actions-fallida.png)

**3. Ejecución exitosa tras la corrección**
Commit `<hash>`, `<fecha>`. [Ver ejecución](<URL>)
Al restaurar la aserción, el mismo paso pasó las 3 pruebas y el pipeline volvió
a aprobarse.

![Corregida](docs/07-actions-corregida.png)

## Conclusiones
El pipeline detectó automáticamente el error: falló en el paso de pruebas y el
log indicó la causa y la línea exacta. Tras corregirlo y hacer un nuevo commit,
volvió a aprobarse. La integración continua permite detectar errores de forma
temprana y ejecutar las pruebas siempre en un entorno limpio y reproducible.