// Contenido del informe final y de los manuales de CodeLingua.
// Marcado en línea: **negrita** y `código`.
const h1 = x => ({ t: 'h1', x })
const h2 = x => ({ t: 'h2', x })
const p = x => ({ t: 'p', x })
const ul = (...items) => ({ t: 'ul', items })
const ol = (...items) => ({ t: 'ol', items })
const table = (head, rows, widths) => ({ t: 'table', head, rows, widths })
const img = (src, cap, o = {}) => ({ t: 'img', src, cap, ...o })
const code = x => ({ t: 'code', x })

export const informe = [
  h1('Fundamentación'),
  p(
    'CodeLingua es una aplicación educativa inspirada en la lógica de aprendizaje progresivo de Duolingo, pero orientada a la enseñanza de lenguajes de programación. Surge para resolver dos barreras habituales: la curva de entrada exigente (mucha teoría y herramientas antes de escribir el primer programa) y la falta de motivación sostenida cuando no se percibe un avance concreto. La mascota oficial es **Usagi**, del anime Chiikawa.'
  ),
  p(
    'La aplicación se desarrolla con Quasar (Vue 3 + Vite) y se empaqueta como APK Android con Capacitor. El backend (base de datos relacional, autenticación, permisos y tiempo real) se implementa con Supabase. Este documento corresponde a la **Etapa 8**: empaquetado Android desde terminal, ensayos, versión release firmada, manuales, informe final y defensa. Reúne las entregas anteriores y las ampliaciones sin rehacer lo aprobado.'
  ),
  p(
    'Se distingue lo comprobado con evidencia de lo que sigue pendiente de prueba. Los pendientes no se presentan como aprobados.'
  ),

  h1('Alcance'),
  p('El sistema comprende los siguientes módulos funcionales:'),
  ul(
    '**Catálogo y contenido:** curso, unidades, lecciones, actividades de opción múltiple con retroalimentación inmediata. El contenido vive en Supabase y se consulta de forma asíncrona.',
    '**Acceso e identidad:** visitante (solo lectura), invitado con sesión anónima y cuenta permanente con correo y contraseña; alias público `alias#sufijo`; recuperación de contraseña.',
    '**Práctica con progreso:** intentos y respuestas guardados en el servidor; aprobación con 60 % de aciertos que habilita la lección siguiente.',
    '**Competencia de expo:** eventos, desafíos con reglas propias (duración, puntos, intentos), partidas con reloj y puntaje calculados por el servidor.',
    '**Ranking público en vivo:** pantalla de solo lectura que se actualiza por Realtime con el mejor intento válido de cada participante.',
    '**Administración:** panel `/admin` para eventos, desafíos, preguntas, opciones y soluciones, protegido por `es_admin()` y RLS.',
    '**Aplicación Android:** APK debug para ensayos y APK release firmado para la entrega pública, con enlaces de confirmación y recuperación mediante `doulingo://auth/callback`.'
  ),
  p(
    'Quedan para versiones posteriores: más cursos y lenguajes (Python, HTML/CSS), rachas persistentes, notificaciones, publicación en tienda y panel de estadísticas (ver *Mejoras pendientes*).'
  ),

  h1('Objetivo'),
  p(
    'Desarrollar una aplicación móvil que permita a una persona sin conocimientos previos aprender fundamentos de programación en sesiones breves, con retroalimentación inmediata y progreso guardado, y que además permita realizar una competencia presencial (expo) con puntajes oficiales calculados en el servidor y un ranking compartido por varios celulares, protegiendo en la propia base de datos las respuestas correctas y los resultados.'
  ),

  h1('Organigrama de roles'),
  p(
    'El sistema define cuatro perfiles de acceso. El visitante solo lee contenido publicado; el invitado y el participante registrado practican y compiten con identidad propia; el administrador prepara el contenido y los eventos. La autorización se aplica en dos capas: la interfaz (rutas y menús) y las políticas Row Level Security de PostgreSQL. El rol de administrador vive en la tabla `admin_roles` y no en datos editables por el cliente.'
  ),
  img('01-roles', 'Roles del sistema y alcance de cada perfil.'),

  h1('Análisis de stakeholders'),
  p(
    'Los principales stakeholders son quienes participan en la expo, el organizador/administrador, el equipo de desarrollo, la institución que recibe la demostración y quienes mantendrán el proyecto.'
  ),
  h2('Clasificación'),
  table(
    ['Categoría', 'Stakeholders'],
    [
      [
        'Alto poder · Alto interés',
        'Organizador/administrador de la expo, equipo de desarrollo, institución que evalúa'
      ],
      [
        'Alto interés · Poder medio o bajo',
        'Participantes (invitados y registrados): usan la app y sus necesidades definen la experiencia'
      ],
      [
        'Poder medio · Interés medio',
        'Docentes o jurado que observan el ranking en vivo'
      ],
      [
        'Bajo poder · Interés medio',
        'Público general que podría instalar el APK en el futuro'
      ]
    ],
    [30, 70]
  ),

  h1('Historias de usuario'),
  table(
    ['ID', 'Como…', 'Quiero…', 'Para…', 'Criterio de aceptación'],
    [
      [
        'HU01',
        'Visitante',
        'ver los cursos y unidades publicados',
        'conocer la propuesta sin registrarme',
        'Se listan solo cursos disponibles; no se exponen soluciones'
      ],
      [
        'HU02',
        'Participante',
        'ingresar como invitado',
        'practicar de inmediato',
        'Se crea sesión anónima y un alias `invitado#xxxx`'
      ],
      [
        'HU03',
        'Participante',
        'registrarme con correo y contraseña',
        'conservar mi identidad e historial',
        'Misma identidad del invitado; correo de confirmación abre la app'
      ],
      [
        'HU04',
        'Participante',
        'recuperar mi contraseña',
        'volver a entrar si la olvido',
        'El enlace abre `doulingo://auth/callback` y pide la contraseña nueva'
      ],
      [
        'HU05',
        'Participante',
        'resolver una lección con devolución inmediata',
        'saber si acerté y por qué',
        'Cada respuesta muestra correcto/incorrecto y la explicación'
      ],
      [
        'HU06',
        'Participante',
        'que mi avance se guarde',
        'retomarlo más tarde',
        'El resultado se confirma como guardado en el servidor'
      ],
      [
        'HU07',
        'Participante',
        'aprobar para desbloquear la siguiente lección',
        'avanzar de forma progresiva',
        'Con 60 % o más se habilita la siguiente; progreso nunca baja'
      ],
      [
        'HU08',
        'Participante',
        'jugar un desafío con tiempo y puntos',
        'competir en la expo',
        'Reloj y puntaje los calcula el servidor; una respuesta por pregunta'
      ],
      [
        'HU09',
        'Participante',
        'ver mi puntaje e historial',
        'comparar mis intentos',
        'El perfil muestra partidas, puntos y respuestas'
      ],
      [
        'HU10',
        'Público',
        'ver el ranking en una pantalla',
        'seguir la competencia',
        'Se actualiza por Realtime; muestra solo posición, alias y puntaje'
      ],
      [
        'HU11',
        'Administrador',
        'crear y editar eventos, desafíos y preguntas',
        'preparar la expo',
        'Solo cuentas admin escriben; el contenido incompleto no se publica'
      ],
      [
        'HU12',
        'Administrador',
        'cerrar el evento',
        'terminar la competencia',
        'Estado “cerrado”: se revelan soluciones y el ranking queda de solo lectura'
      ],
      [
        'HU13',
        'Participante',
        'usar la app como APK en mi celular',
        'jugar sin navegador',
        'El APK no depende del servidor de desarrollo y funciona con Atrás y teclado'
      ],
      [
        'HU14',
        'Organizador',
        'conservar y respaldar los resultados',
        'tener evidencia después de la expo',
        'Existe un procedimiento de respaldo sin secretos'
      ]
    ],
    [7, 12, 24, 22, 35]
  ),

  h1('Cronograma'),
  p(
    'El cronograma se reconstruyó a partir del historial de Git del repositorio. Cada barra cubre el período entre un hito y el anterior.'
  ),
  img(
    '06-cronograma',
    'Cronograma real del proyecto (septiembre – noviembre de 2026).'
  ),

  h1('Revisión final del sistema'),
  h2('Funcionalidades'),
  table(
    ['Área', 'Estado'],
    [
      [
        'Landing, catálogo, unidades y lecciones (3 fases: introducción, actividades y resultados)',
        'Implementado. 26/26 casos de interfaz en la corrida automatizada de la etapa 3.'
      ],
      [
        'Contenido en Supabase con RLS y `check_answer()`',
        'Implementado. Las soluciones no se descargan al cliente.'
      ],
      [
        'Autenticación: invitado, registro, inicio de sesión, recuperación, alias',
        'Implementado. Pruebas de correo limitadas por el cupo de 2 correos por hora de Supabase.'
      ],
      [
        'Intentos, respuestas y progreso en servidor',
        'Implementado (35 + 14 + 5 casos en la última ejecución registrada).'
      ],
      [
        'Competencia de expo: eventos, desafíos, partidas, ranking por desafío',
        'Implementado.'
      ],
      [
        'Ranking público en vivo y panel de administración',
        'Implementado (migraciones 0008 y 0009).'
      ],
      [
        'APK Capacitor con deep link `doulingo://`',
        'Implementado. Debug y release firmado generados desde terminal.'
      ],
      [
        'Ensayo en dos celulares físicos',
        '**Pendiente** (no había dispositivos conectados). Ver checklist en *Pruebas*.'
      ]
    ],
    [55, 45]
  ),
  h2('Verificaciones de esta etapa (17/11/2026)'),
  table(
    ['Verificación', 'Resultado'],
    [
      ['`oxlint` (análisis estático)', 'Sin errores.'],
      [
        '`oxfmt` (formato)',
        '17 archivos fuera de formato detectados; se aplicó `oxfmt` y quedó sin diferencias.'
      ],
      ['`npm run build` (SPA de Quasar)', 'Correcto.'],
      [
        '`quasar build -m capacitor -T android --skip-pkg` + `cap sync`',
        'Correcto. Recursos web copiados a `assets/public`.'
      ],
      [
        '`gradlew assembleDebug` con el Wrapper',
        '**BUILD SUCCESSFUL.** `app-debug.apk`, 6,3 MB.'
      ],
      [
        '`gradlew assembleRelease` con clave propia',
        '**BUILD SUCCESSFUL.** `app-release.apk`, 4,5 MB, firma verificada con `apksigner`.'
      ],
      [
        '`aapt2 dump badging` del release',
        '`com.doulingo.app`, versionCode 1, versionName 1.0, minSdk 24, targetSdk 36.'
      ],
      [
        '`adb devices`',
        'Sin dispositivos físicos conectados. Instalación en celulares **no certificada**.'
      ],
      [
        'Pruebas e2e contra Supabase (proyecto reactivado)',
        '10 suites ejecutadas: 222 casos OK y 7 omitidos por el cupo de correos. Ver *Pruebas*.'
      ]
    ],
    [42, 58]
  ),

  h1('Arquitectura del sistema'),
  p(
    'La aplicación es una SPA de Quasar que se ejecuta en un navegador o, empaquetada con Capacitor, dentro de un WebView Android (`https://localhost`). Las pantallas nunca hablan directamente con la base: piden datos a repositorios (`src/data`), que centralizan las consultas y las llamadas RPC a Supabase. El cliente solo contiene la URL del proyecto y la publishable key; nunca una clave `service_role`.'
  ),
  img('02-arquitectura', 'Arquitectura: cliente Quasar/Capacitor y Supabase.'),
  p(
    'La política de seguridad se aplica en el servidor: las tablas tienen RLS, las operaciones críticas son funciones `SECURITY DEFINER` que validan identidad y reglas, y el cliente no puede insertar ni modificar puntajes oficiales por REST.'
  ),
  h2('Flujo de una partida y del ranking'),
  img(
    '04-partida-ranking',
    'Dos celulares guardan resultados en la misma base y el ranking se actualiza por Realtime.'
  ),
  h2('Flujo de los enlaces de confirmación y recuperación'),
  img('05-deep-link', 'Deep link de autenticación dentro del APK.'),

  h1('Modelo de base de datos'),
  p(
    'El modelo separa dos mundos: el contenido educativo y el progreso de práctica (diagrama 1) y la competencia de expo con sus resultados públicos y roles administrativos (diagrama 2). La identidad vive en `auth.users` de Supabase y `perfiles` guarda solo el alias visible.'
  ),
  img(
    '07-der-contenido',
    'Diagrama entidad-relación 1: contenido, práctica y progreso.',
    { landscape: true }
  ),
  img(
    '08-der-competencia',
    'Diagrama entidad-relación 2: competencia de expo, ranking y administración.',
    { landscape: true }
  ),
  h2('Diccionario de datos (resumen)'),
  table(
    ['Tabla', 'Campos principales', 'Restricciones clave'],
    [
      [
        'cursos',
        'id, slug, titulo, descripcion, nivel, estado, color, icono, orden',
        'slug UNIQUE; estado disponible/proximamente; color hex; orden > 0'
      ],
      [
        'unidades',
        'id, curso_id→cursos, orden, titulo, descripcion, icono, disponible',
        'UNIQUE(curso_id, orden); cascade'
      ],
      [
        'lecciones',
        'id, unidad_id→unidades, orden, titulo, explicacion, ejemplo_codigo',
        'UNIQUE(unidad_id, orden)'
      ],
      [
        'preguntas',
        'id, leccion_id→lecciones, orden, enunciado, codigo',
        'UNIQUE(leccion_id, orden)'
      ],
      [
        'opciones',
        'id, pregunta_id→preguntas, orden, texto',
        'UNIQUE(pregunta_id, orden); sin marca de solución'
      ],
      [
        'soluciones',
        'pregunta_id→preguntas, opcion_correcta_id→opciones, explicacion',
        '1 a 1; RLS sin lectura y permisos revocados'
      ],
      [
        'perfiles',
        'id→auth.users, alias, alias_sufijo, es_invitado, creado_en',
        'alias `^[a-z0-9_]{3,20}$`; UNIQUE(alias, alias_sufijo)'
      ],
      [
        'participant_progress',
        'id→auth.users, leccion_id→lecciones, estado, intentos, mejor_aciertos, total_actividades',
        'PK(id, leccion_id); estado intentada/aprobada'
      ],
      [
        'intentos',
        'id, participante_id, leccion_id, clave_idempotencia, estado, aciertos, errores, aprobada, iniciado_en, finalizado_en',
        'UNIQUE(participante, clave); aciertos+errores ≤ total'
      ],
      [
        'intentos_respuestas',
        'id, intento_id, actividad_id, opcion_id, correcto, respondido_en',
        'UNIQUE(intento, actividad): la primera queda firme'
      ],
      [
        'eventos',
        'id, slug, titulo, inicia_en, termina_en, estado, es_prueba',
        'estado borrador/publicado/cerrado; termina_en > inicia_en'
      ],
      [
        'desafios',
        'id, evento_id, slug, dificultad, duracion_segundos, puntos_por_acierto, intentos_permitidos, tolerancia_segundos, estado, orden',
        'UNIQUE(evento, slug); valores > 0'
      ],
      [
        'desafio_preguntas',
        'id, desafio_id, orden, enunciado, codigo, dificultad',
        'UNIQUE(desafio, orden); banco independiente de la práctica'
      ],
      [
        'desafio_opciones',
        'id, pregunta_id, orden, texto',
        'UNIQUE(pregunta, orden)'
      ],
      [
        'desafio_soluciones',
        'pregunta_id, opcion_correcta_id, explicacion',
        'Privada: sin lectura por API'
      ],
      [
        'partidas',
        'id, participante_id, desafio_id, clave_idempotencia, estado, puntos, aciertos, errores, reglas fijadas, iniciado_en, expira_en, finalizado_en, duracion_ms',
        'estado en_curso/finalizada/incompleta/vencida; UNIQUE(participante, clave)'
      ],
      [
        'partida_preguntas',
        'partida_id, desafio_pregunta_id, orden',
        'PK compuesta; fija las preguntas de la partida'
      ],
      [
        'partida_respuestas',
        'id, partida_id, desafio_pregunta_id, desafio_opcion_id, correcto, puntos_obtenidos, tiempo_ms',
        'UNIQUE(partida, pregunta); FK a partida_preguntas'
      ],
      [
        'resultados_publicos',
        'id, evento_id, desafio, alias, puntos, duracion_ms, finalizado_en',
        'Proyección pública sin UUID de participantes; Realtime'
      ],
      [
        'admin_roles',
        'user_id→auth.users, rol, asignado_en',
        'rol admin/editor; sin acceso para anon/authenticated'
      ]
    ],
    [18, 46, 36]
  ),
  h2('Decisiones de diseño'),
  ul(
    '**Dos bancos de preguntas:** la competencia usa `desafio_*` y nunca pasa por `check_answer()`, de modo que practicar no revela respuestas del desafío.',
    '**Soluciones privadas:** la respuesta correcta vive en tablas sin política de lectura; solo la entregan funciones `SECURITY DEFINER`.',
    '**Foto de reglas en la partida:** duración, puntos y tolerancia se copian a `partidas` para que editar un desafío no altere partidas existentes.',
    '**Proyección pública:** `resultados_publicos` evita exponer partidas, correos, respuestas o identificadores privados en el ranking.',
    '**Idempotencia:** `clave_idempotencia` y restricciones UNIQUE evitan duplicados ante reintentos o dobles toques.'
  ),

  h1('Reglas de negocio'),
  table(
    ['ID', 'Regla', 'Dónde se aplica'],
    [
      [
        'RN01',
        'Una lección se aprueba con aciertos ≥ ceil(actividades × 0,6).',
        'Función `finalizar_intento`'
      ],
      [
        'RN02',
        'Solo las lecciones aprobadas habilitan la siguiente; el progreso nunca baja.',
        '`participant_progress` + interfaz'
      ],
      [
        'RN03',
        'La corrección de respuestas la hace el servidor; el cliente no conoce la solución.',
        '`check_answer`, `registrar_respuesta`'
      ],
      [
        'RN04',
        'Una respuesta por actividad e intento; la primera queda firme.',
        'UNIQUE + RPC'
      ],
      [
        'RN05',
        'Iniciar o finalizar dos veces con la misma clave devuelve el mismo resultado.',
        '`clave_idempotencia`'
      ],
      [
        'RN06',
        'El reloj oficial es el del servidor; se admite una tolerancia configurable.',
        '`iniciar_partida`, `responder_partida`'
      ],
      [
        'RN07',
        'Una respuesta por pregunta de partida; el envío repetido no suma de nuevo.',
        '`partida_respuestas`'
      ],
      [
        'RN08',
        'Los intentos por desafío están limitados por `intentos_permitidos`.',
        '`iniciar_partida`'
      ],
      [
        'RN09',
        'El ranking usa el mejor intento válido (finalizada) de cada participante.',
        '`publicar_resultado`, `ranking_evento`'
      ],
      [
        'RN10',
        'Desempate: mayor puntaje, menor duración medida por el servidor, finalización más temprana.',
        '`ranking_evento`'
      ],
      [
        'RN11',
        'Las partidas incompletas o vencidas no compiten pero quedan en el historial.',
        'Estados de `partidas`'
      ],
      [
        'RN12',
        'Soluciones y explicaciones del desafío se revelan al cerrar el evento.',
        '`resultado_partida`'
      ],
      [
        'RN13',
        'El alias público tiene 3 a 20 caracteres `[a-z0-9_]` y un sufijo de 4 hexadecimales.',
        '`perfiles` + `normalizar_alias`'
      ],
      [
        'RN14',
        'Solo `admin_roles` otorga permisos de administración; el cliente no puede asignarlos.',
        '`es_admin()`'
      ],
      [
        'RN15',
        'No se publica una lección o desafío sin preguntas y solución válida.',
        '`validar_*_publicable`'
      ],
      [
        'RN16',
        'Los eventos y desafíos `es_prueba` se ocultan en la interfaz de la expo.',
        'Interfaz + consultas'
      ]
    ],
    [8, 62, 30]
  ),

  h1('Seguridad'),
  table(
    ['Riesgo', 'Control aplicado'],
    [
      [
        'Leer las respuestas correctas desde la API',
        'RLS sin política de lectura en `soluciones` y `desafio_soluciones` + `REVOKE`; solo RPC `SECURITY DEFINER`.'
      ],
      [
        'Modificar puntajes o partidas por REST',
        'Sin políticas de escritura para `anon`/`authenticated`; todo pasa por RPC que valida pertenencia y estado.'
      ],
      [
        'Ver datos de otros participantes',
        'RLS por `auth.uid()` en perfiles, intentos y partidas.'
      ],
      [
        'Escalada a administrador',
        'Rol en `admin_roles`, consultado por `es_admin()`; se asigna solo desde SQL del propietario.'
      ],
      [
        'Exponer datos privados en el ranking',
        '`resultados_publicos` publica solo alias, puntos y duración.'
      ],
      [
        'Doble envío o repetición de enlaces',
        'Idempotencia en servidor y deduplicación del deep link en el cliente (ventana de 10 s).'
      ],
      [
        'Trampas con el reloj del cliente',
        'Tiempo oficial calculado por el servidor (`hora_servidor`).'
      ],
      [
        'Filtrar secretos',
        '`.env`, `*.jks`, `*.keystore` y `signing.properties` fuera de Git; el cliente solo usa la publishable key.'
      ],
      [
        'Pérdida de la clave de firma',
        'Keystore fuera del repositorio con respaldo cifrado; sin ella no se pueden publicar actualizaciones.'
      ]
    ],
    [34, 66]
  ),

  h1('Empaquetado Android con Capacitor y Gradle'),
  p(
    'El APK se genera completamente desde terminal, sin Android Studio. Se usa el Gradle Wrapper incluido en `src-capacitor/android`; no hace falta instalar Gradle de forma global.'
  ),
  img('03-pipeline-apk', 'Pipeline de empaquetado: del código fuente al APK.'),
  h2('Versiones registradas'),
  table(
    ['Componente', 'Versión', 'Nota'],
    [
      ['Node.js', '24.16.0', 'Cumple `engines` del proyecto'],
      ['Quasar / CLI', '2.32.0 / @quasar/app-vite 3.8.3', 'Modo Capacitor'],
      ['Capacitor', '8.5.3', '`@capacitor/android`, CLI y plugin App 8.1.2'],
      ['JDK', 'Eclipse Temurin 21.0.12+8', '`JAVA_HOME`'],
      ['Gradle Wrapper', '8.14.3', 'Incluido en el proyecto Android'],
      [
        'Android Gradle Plugin',
        '8.13.0',
        'Compatible con Gradle 8.14.3 y JDK 21'
      ],
      ['Command-line Tools', '22.0', '`cmdline-tools/latest`'],
      ['Platform-Tools', '37.0.0', 'Incluye `adb`'],
      ['Plataforma Android', 'API 36', 'compileSdk/targetSdk 36; minSdk 24'],
      ['Build-Tools', '36.0.0', '`aapt2`, `apksigner`']
    ],
    [28, 34, 38]
  ),
  h2('Identidad de la aplicación'),
  ul(
    'Nombre: **CodeLingua** (antes Doulingo); `appId`: `com.doulingo.app`; versionCode 1; versionName 1.0. El `appId`, el esquema `doulingo://` y la clave de firma conservan el nombre técnico original para no invalidar la firma ni los enlaces configurados en Supabase.',
    'Ícono adaptativo y heredado con el logo de CodeLingua (Usagi con birrete y laptop) sobre fondo blanco.',
    'Esquema propio: `doulingo://auth/callback` declarado en el `intent-filter` de `MainActivity` y en Supabase (Redirect URLs).'
  ),
  h2('Procedimiento en Windows (PowerShell)'),
  code(`$env:JAVA_HOME = 'C:\\Program Files\\Eclipse Adoptium\\jdk-21.0.12.8-hotspot'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\\Android\\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"

npx quasar build -m capacitor -T android --skip-pkg   # web + cap sync
cd src-capacitor\\android
.\\gradlew.bat assembleDebug --no-daemon              # APK debug`),
  h2('Procedimiento en Linux / macOS'),
  code(`export JAVA_HOME=/usr/lib/jvm/temurin-21
export ANDROID_HOME=$HOME/Android/Sdk ANDROID_SDK_ROOT=$HOME/Android/Sdk
yes | sdkmanager --licenses
npx quasar build -m capacitor -T android --skip-pkg
cd src-capacitor/android
./gradlew assembleDebug`),
  p(
    'El APK queda en `src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk`. Los recursos web se copian a `app/src/main/assets/public/` y el `capacitor.config.json` empacado no declara `server.url`: el APK sirve esos archivos localmente y **no depende del servidor de desarrollo** de la computadora. `local.properties` debe usar barras `/` en `sdk.dir`.'
  ),
  h2('Instalación y verificación'),
  code(`adb devices
adb install -r src-capacitor/android/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.doulingo.app/.MainActivity
adb shell am start -a android.intent.action.VIEW -d "doulingo://auth/callback?code=prueba"
aapt2 dump badging app-debug.apk
apksigner verify --print-certs app-release.apk`),
  h2('Versión release firmada'),
  p(
    'La clave release es distinta de la clave debug. Se genera una sola vez con `keytool`, se guarda **fuera del repositorio** y se respalda de forma segura: sin ella no se pueden publicar actualizaciones de la misma app. Las credenciales se pasan por variables de entorno de la terminal actual; Gradle falla si faltan.'
  ),
  code(`$key = "$env:USERPROFILE\\.android\\doulingo-release.jks"
keytool -genkeypair -keystore $key -alias doulingo -keyalg RSA -keysize 4096 -validity 10000
$env:DOULINGO_KEYSTORE_FILE = $key
$env:DOULINGO_KEY_ALIAS = 'doulingo'
$env:DOULINGO_KEYSTORE_PASSWORD = '<contraseña>'
$env:DOULINGO_KEY_PASSWORD = '<contraseña>'
cd src-capacitor\\android
.\\gradlew.bat assembleRelease
# resultado: app\\build\\outputs\\apk\\release\\app-release.apk`),
  h2('Registro de la ejecución del 17/11/2026'),
  ul(
    '`assembleDebug`: BUILD SUCCESSFUL, `app-debug.apk` de 6,3 MB firmado con el certificado Android Debug.',
    '`assembleRelease`: BUILD SUCCESSFUL, `app-release.apk` de 4,5 MB; `apksigner verify` válido con certificado `CN=CodeLingua` (SHA-256 `4fa56639…d171f0`).',
    '`aapt2`: `com.doulingo.app`, versionCode 1, versionName 1.0, minSdk 24, targetSdk 36.',
    '`assets/public/index.html` y `assets/capacitor.config.json` presentes dentro del APK.',
    'Advertencia no fatal de Gradle (`flatDir`) proveniente del wiring de Capacitor/Cordova.',
    'Keystore y contraseñas guardados en `%USERPROFILE%\\.android\\` (fuera del repositorio); `git status` no muestra archivos de clave.'
  ),

  h1('Pruebas'),
  h2('Suites automatizadas contra Supabase'),
  p(
    'Las suites usan Puppeteer con el navegador del sistema y el proyecto real de Supabase; los desafíos `es_prueba` permiten jugar, vencer y agotar intentos sin tocar los datos públicos de la expo.'
  ),
  table(
    ['Suite', 'Qué comprueba', 'Último resultado registrado'],
    [
      [
        'buttons.mjs',
        'Recorrido de interfaz y estados de la lección',
        '26/26 OK'
      ],
      ['dbtest.mjs', 'Contenido publicado, RLS y `check_answer`', '25/25 OK'],
      ['case7.mjs', 'Fallo de red al comprobar una respuesta', '5/5 OK'],
      [
        'auth.mjs',
        'Invitado, registro, login, recuperación, conversión',
        '16/16 OK (7 omitidos por cupo de correo)'
      ],
      [
        'auth_ui.mjs · alias.mjs',
        'Pantalla de acceso; alias y sufijo',
        '5/5 · 11/11 OK'
      ],
      [
        'attempts.mjs · attempts_ui.mjs',
        'Intentos, idempotencia, progreso, aislamiento',
        '35/35 · 14/14 OK'
      ],
      [
        'challenges.mjs · challenges_ui.mjs',
        'Partidas, doble envío, dos jugadores, vencida, ranking, puntajes bloqueados',
        '60/60 · 25/25 OK'
      ]
    ],
    [26, 46, 28]
  ),
  p(
    '**Ejecución del 17/11/2026** contra el proyecto Supabase reactivado: 222 casos OK (26 + 25 + 5 + 11 + 5 + 35 + 14 + 60 + 25 + 16) y 7 omitidos por el cupo de 2 correos por hora (recuperación y conversión de cuenta). En `challenges_ui.mjs` fallaron 6 comprobaciones porque la interfaz muestra los textos en mayúsculas (CSS) y la prueba distinguía mayúsculas; se corrigió la prueba, no la aplicación, y quedó 25/25.'
  ),
  h2('Verificación en emulador (22/10/2026)'),
  ul(
    'AVD Pixel 6, Android 16 (API 36). Deep link con la app abierta y en arranque en frío procesado; enlace falso muestra aviso en español; enlace repetido se ignora.',
    'Invitado creado desde el APK, sesión persistente tras `force-stop` y reapertura.'
  ),
  h2('Checklist en celulares físicos (pendiente)'),
  p(
    'Completar con al menos dos celulares reales instalando la misma build. Anotar modelo, versión de Android, fecha y resultado. Hasta hacerlo físicamente, estos pasos **no están certificados**.'
  ),
  table(
    ['Prueba', 'Celular 1', 'Celular 2'],
    [
      ['Instalación del APK y apertura', '☐', '☐'],
      ['Acceso a Supabase (cursos cargan)', '☐', '☐'],
      ['Ingreso como invitado', '☐', '☐'],
      ['Registro con correo y confirmación por enlace', '☐', '☐'],
      ['Recuperación de contraseña por enlace', '☐', '☐'],
      ['Preguntas de práctica y retroalimentación', '☐', '☐'],
      ['Progreso guardado y lección siguiente habilitada', '☐', '☐'],
      ['Partida de desafío con puntaje del servidor', '☐', '☐'],
      ['Aparición en el ranking público (ambos celulares)', '☐', '☐'],
      ['Botón Atrás (pantallas internas, inicio, salida)', '☐', '☐'],
      ['Teclado: no tapa campos ni botones', '☐', '☐'],
      ['Pantalla pequeña (≤ 360 dp) y giro', '☐', '☐'],
      ['Cierre y reapertura (partida en curso, sesión)', '☐', '☐'],
      ['Modo avión durante la partida y reconexión', '☐', '☐']
    ],
    [60, 20, 20]
  ),
  p(
    '**Puntos a observar:** el botón Atrás usa el comportamiento por defecto de Capacitor (retrocede en el historial del WebView y sale de la app al llegar al inicio); no hay un manejador propio. `MainActivity` no define `windowSoftInputMode`; si el teclado tapa campos, agregar `adjustResize`. Ambos son candidatos de mejora si el ensayo físico los confirma.'
  ),

  h1('Demostración funcional'),
  p(
    'Usar cuentas de demostración y el desafío de prueba; no usar datos personales en la exposición. Preparar dos celulares con el mismo APK y una pantalla (computadora o tercer celular) con `/#/ranking/<evento>`.'
  ),
  ol(
    '**Visitante:** abrir la app, mostrar catálogo y unidades sin sesión.',
    '**Invitado (celular A):** ingresar como invitado y resolver una lección; mostrar el aviso “Resultado guardado en el servidor” y la lección siguiente habilitada.',
    '**Registro (celular B):** registrar una cuenta, confirmar por el enlace (abre la app por `doulingo://`) y mostrar el perfil con alias.',
    '**Competencia:** ambos celulares juegan el mismo desafío a la vez; mostrar el puntaje devuelto por el servidor.',
    '**Ranking en vivo:** en la tercera pantalla aparecen ambos participantes sin recargar; mostrar el aviso al perder conexión y el botón Actualizar.',
    '**Seguridad:** intentar leer `soluciones` o insertar un puntaje por REST y mostrar el rechazo (RLS).',
    '**Administración:** entrar a `/admin` con cuenta admin; una cuenta común es rechazada.',
    '**Cierre:** cerrar el evento y mostrar que se revelan soluciones y el ranking queda de solo lectura.'
  ),

  h1('Fragmentos de código relevantes'),
  h2('A. Corrección en el servidor · `responder_partida`'),
  p(
    'La respuesta se valida contra la partida del participante, su pertenencia a la partida y la opción de la pregunta; un envío repetido devuelve la respuesta existente sin sumar puntos.'
  ),
  code(`select * into v_partida from public.partidas
 where id = p_partida and participante_id = v_uid
 for update;                           -- bloquea la fila: evita doble suma

select * into v_respuesta from public.partida_respuestas
 where partida_id = p_partida and desafio_pregunta_id = p_pregunta;
if found then  -- reintento: se devuelve lo mismo, repetida = true
  return query select v_respuesta.correcto, v_respuesta.puntos_obtenidos, ...;
end if;
if now() > v_partida.expira_en then
  raise exception 'PR_PARTIDA_EXPIRADA';
end if;`),
  h2('B. Deep link del APK · `src/lib/deepLink.js`'),
  p(
    'Dentro del APK el WebView no ve el query del enlace; se intercepta `appUrlOpen` y se canjea el código PKCE. Un enlace de un solo uso no se reintenta durante 10 s.'
  ),
  code(`const listener = await App.addListener('appUrlOpen', async ({ url }) => {
  const code = extractAuthCode(url)   // query ?code= o fragmento #code=
  if (code) await onCode(code)        // exchangeCodeForSession
})`),
  h2('C. Firma release por variables de entorno · `app/build.gradle`'),
  code(`signingConfigs {
  if (hasReleaseSigning) {
    release {
      storeFile file(releaseSigningValues.keystoreFile)
      storePassword releaseSigningValues.keystorePassword
      keyAlias releaseSigningValues.keyAlias
      keyPassword releaseSigningValues.keyPassword
    }
  }
}`),

  h1('Dificultad técnica y solución'),
  p(
    'El mayor desafío fue que los puntajes de una competencia con varios celulares no podían depender del cliente: cualquiera podría alterar el puntaje, el tiempo o ver la respuesta correcta desde la API. Se resolvió moviendo la lógica al servidor: la partida, las preguntas y las reglas se fijan en `iniciar_partida`, la corrección y el puntaje se calculan en `responder_partida`, el tiempo oficial es el del servidor y las respuestas correctas viven en tablas sin lectura. Un segundo desafío fue hacer funcionar Supabase Auth con PKCE dentro del APK: se configuró `androidScheme: https`, un esquema `doulingo://` propio y un manejador de `appUrlOpen` con deduplicación, porque Android puede notificar el mismo enlace más de una vez. Por último, `local.properties` con barras invertidas rompía Gradle en Windows (se documentó el uso de `/`).'
  ),

  h1('Resultados frente a los objetivos iniciales'),
  ul(
    '**Logrado:** aprendizaje progresivo con retroalimentación inmediata, progreso guardado y reglas de aprobación.',
    '**Logrado:** identidad con invitado y cuenta permanente sin perder el historial.',
    '**Logrado:** competencia con puntaje, tiempo y ranking calculados por el servidor y pantalla en vivo.',
    '**Logrado:** APK debug y release firmado generados desde terminal con el Wrapper, sin Android Studio.',
    '**Verificado hoy:** análisis estático, formato, build web, build Capacitor, debug y release firmado y 222 casos e2e contra Supabase.'
  ),
  h2('Pendiente'),
  ul(
    'Verificar en el proyecto activo las migraciones 0008 y 0009 (ranking público y administración) y la publicación Realtime de `resultados_publicos`; las suites automáticas cubren hasta la 0006.',
    'Instalar el APK en al menos dos celulares físicos y completar el checklist.',
    'Probar registro y recuperación con correo real (SMTP propio o cupo disponible).',
    'Respaldar la clave release en un lugar seguro adicional.'
  ),

  h1('Cierre de la expo'),
  p(
    'Cerrada la expo se revisa el estado general, se conservan los registros necesarios y se anotan problemas y mejoras para la siguiente versión.'
  ),
  table(
    ['Paso', 'Acción', 'Resultado esperado'],
    [
      [
        '1',
        'Cambiar el estado del evento a **Cerrado** desde `/admin`.',
        'Se revelan soluciones; no entran partidas nuevas.'
      ],
      [
        '2',
        'Verificar el ranking final contra la lista de alias anunciada.',
        'Sin correos ni datos privados visibles.'
      ],
      [
        '3',
        'Exportar resultados y contenido sin secretos (`supabase db dump --data-only --schema public`).',
        'Respaldo guardado fuera del repositorio.'
      ],
      [
        '4',
        'Registrar capturas del ranking y de la lista de dispositivos usados.',
        'Evidencia para el informe.'
      ],
      [
        '5',
        'Revisar cuentas de invitado y de prueba; dar de baja lógica lo que corresponda.',
        'Sin borrar el historial de partidas.'
      ],
      [
        '6',
        'Conservar la clave release y su respaldo; registrar versión publicada.',
        'Actualizaciones futuras posibles.'
      ],
      [
        '7',
        'Completar el registro de problemas y mejoras.',
        'Lista priorizada para la versión 2.'
      ]
    ],
    [8, 56, 36]
  ),
  h2('Registro de problemas y mejoras'),
  table(
    ['ID', 'Hallazgo', 'Estado'],
    [
      [
        'P01',
        'El dominio del proyecto Supabase no resolvía en DNS (17/11/2026, proyecto pausado).',
        'Resuelto: proyecto reactivado y suites re-ejecutadas'
      ],
      [
        'P07',
        'Seis comprobaciones de `challenges_ui.mjs` distinguían mayúsculas y la interfaz muestra textos en mayúsculas.',
        'Corregido en la prueba (25/25)'
      ],
      [
        'P02',
        '17 archivos estaban fuera del formato de `oxfmt`.',
        'Corregido con `oxfmt`'
      ],
      [
        'P03',
        'Sin dispositivos físicos para el ensayo del APK.',
        'Abierto: ejecutar el checklist'
      ],
      [
        'P04',
        'Límite de 2 correos por hora en Supabase para pruebas de registro y recuperación.',
        'Mitigar con SMTP propio'
      ],
      ['P05', 'Advertencia `flatDir` de Gradle (no fatal).', 'Aceptado'],
      [
        'P06',
        'Sin manejador explícito del botón Atrás ni `windowSoftInputMode`.',
        'Verificar en celular; mejora si hace falta'
      ]
    ],
    [8, 62, 30]
  ),

  h1('Mejoras para futuras versiones'),
  ul(
    'Más unidades, cursos y lenguajes; ejercicios de completar código.',
    'Rachas y logros persistentes en la base.',
    'Manejador propio del botón Atrás con confirmación al salir de una partida.',
    'Publicación en Google Play (App Bundle `bundleRelease`) y actualización de versión.',
    'Panel de estadísticas del evento y exportación de resultados.',
    'Modo sin conexión para práctica con sincronización posterior.',
    'Pruebas automáticas en CI y pruebas instrumentadas en dispositivo.'
  ),

  h1('Preparación de la defensa oral'),
  ol(
    '**¿Por qué las respuestas correctas no están en el cliente?** Para que nadie pueda leerlas desde la API; solo las entregan funciones del servidor.',
    '**¿Cómo se evita que un celular altere su puntaje?** El cliente solo envía IDs; el servidor valida, corrige, suma y mide el tiempo.',
    '**¿Qué pasa si se toca dos veces “Confirmar”?** Una respuesta por pregunta (UNIQUE) y la primera queda firme.',
    '**¿Cómo aparece un puntaje en el ranking de otro equipo?** Un trigger publica el mejor intento en `resultados_publicos` y Realtime avisa a la pantalla.',
    '**¿Qué diferencia hay entre invitado y registrado?** Ambos tienen identidad en Supabase Auth; el registrado conserva credenciales y puede recuperar el acceso.',
    '**¿Cómo se abre la app desde el correo?** Esquema `doulingo://auth/callback` en el `intent-filter` y `appUrlOpen` en Capacitor.',
    '**¿Por qué el APK no depende de tu computadora?** Los recursos web están en `assets/public` y no hay `server.url`.',
    '**¿Dónde está la clave de firma y qué pasa si se pierde?** Fuera de Git, con respaldo; sin ella no se actualiza la app.',
    '**¿Qué falta validar?** Ensayo en celulares físicos y migraciones 0008/0009 en el proyecto activo.'
  ),

  h1('Correspondencia con la consigna de la Etapa 8'),
  table(
    ['Punto de la consigna', 'Dónde está'],
    [
      [
        'Registrar versiones, instalar SDK y herramientas',
        'Sección *Empaquetado Android* y `docs/12-apk.md`'
      ],
      [
        'Rutas de JDK/SDK, licencias y Gradle Wrapper',
        'Procedimiento en Windows y Linux'
      ],
      [
        'Modo Capacitor, identificador, nombre, ícono y versión',
        'Identidad de la aplicación'
      ],
      [
        'Recursos web empacados, sin servidor de desarrollo',
        'Registro de la ejecución'
      ],
      [
        '`assembleDebug` con el Wrapper y ubicación del APK',
        'Procedimiento y registro'
      ],
      [
        'Instalación en dos celulares y verificaciones',
        'Checklist (pendiente de ejecución física)'
      ],
      [
        'Atrás, teclado, pantallas pequeñas, cierre y errores',
        'Checklist y puntos a observar'
      ],
      [
        'Release firmado y clave fuera del repositorio',
        'Versión release firmada'
      ],
      [
        'Manuales de participantes y administradores',
        '`Manual_Participantes.pdf`, `Manual_Administradores.pdf`'
      ],
      ['Informe final con las entregas y ampliaciones', 'Este documento'],
      ['Defensa y demostración', 'Demostración y preparación de la defensa'],
      [
        'Cierre de la expo y mejoras',
        'Cierre de la expo y registro de problemas'
      ]
    ],
    [50, 50]
  ),

  h1('Entrega'),
  ul(
    'Código y configuración: `src/`, `src-capacitor/`, `package.json`, `quasar.config.js`, `.env.example`.',
    'Base reproducible: `supabase/migrations/0001…0009`, `supabase/setup.sql` y `supabase/README.md`.',
    'Documentación técnica: `docs/01…17` y los diagramas en `docs/diagramas/` (SVG y PNG).',
    'Informe final: `docs/Etapa_Final_Informe.pdf` y `.docx`.',
    'Manuales: `docs/Manual_Participantes.pdf` y `docs/Manual_Administradores.pdf`.',
    'APK: `app-debug.apk` (ensayos) y `app-release.apk` (entrega pública), generados con los comandos de este informe. La clave de firma **no** se entrega ni se versiona.'
  ),
  p(
    '**Reproducción:** `npm ci` → configurar `.env` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`) → `npm run dev` o los comandos de empaquetado. Nunca versionar `.env`, claves ni keystores.'
  ),

  h1('Conclusión'),
  p(
    'CodeLingua cumple el recorrido completo de la Etapa 8 en lo técnico: la aplicación se empaqueta como APK desde terminal con el Gradle Wrapper, existe una versión release firmada con la clave resguardada fuera del repositorio, la seguridad de los puntajes y de las respuestas se garantiza en PostgreSQL y el ranking se comparte entre celulares en tiempo real. Lo que falta para cerrar con evidencia es operativo: completar el ensayo en celulares físicos y verificar en el proyecto activo las migraciones 0008 y 0009. El informe deja el procedimiento, el checklist y el registro de problemas listos para hacerlo.'
  )
]

export const manualParticipantes = [
  h1('Manual para participantes'),
  p(
    'Guía breve para instalar CodeLingua, jugar en la expo y consultar tus resultados.'
  ),
  h2('1. Instalar e ingresar'),
  ol(
    'Instalá el archivo **CodeLingua** (APK) en tu celular. Si Android lo pide, permití la instalación desde esa fuente.',
    'Abrí la app y entrá a **Expo** para ver los desafíos.',
    'En **Acceso** elegí la pestaña **Invitado** (sin correo, botón CONTINUAR COMO INVITADO), **Crear cuenta** o **Ingresar** con correo y contraseña para conservar tu identidad.'
  ),
  h2('2. Registro y recuperación'),
  ul(
    'Después de registrarte llega un correo: tocá el enlace **en el mismo celular**. Si Android pregunta con qué app abrirlo, elegí **CodeLingua**.',
    'Si olvidaste la contraseña, usá “Olvidé mi contraseña”, abrí el correo en este celular y elegí una nueva.',
    'Tu alias público se muestra como `alias#xxxx`. No uses datos personales en el alias.'
  ),
  h2('3. Practicar'),
  ol(
    'Entrá a **Cursos**, elegí una unidad y una lección.',
    'Leé la explicación, respondé las actividades y tocá **Confirmar**. Verás si acertaste y por qué.',
    'Con 60 % de aciertos o más aprobás y se habilita la lección siguiente.'
  ),
  h2('4. Jugar un desafío'),
  ol(
    'En **Expo** elegí un desafío y leé cantidad de preguntas, duración, puntos e intentos.',
    'Tocá el botón de inicio del desafío. El tiempo oficial lo mide el servidor: cerrar la app no detiene el reloj.',
    'Respondé y confirmá cada pregunta. Al terminar tocá **FINALIZAR PARTIDA** y esperá el mensaje **Resultado guardado en el servidor** antes de salir.'
  ),
  h2('5. Resultado y ranking'),
  ul(
    'Mirá tus puntos y respuestas en la pantalla de resultado y en tu **Perfil** (historial).',
    'El ranking toma tu mejor intento válido. Las partidas incompletas o vencidas no compiten.',
    'La pantalla de ranking se actualiza sola; también podés tocar **Actualizar**.'
  ),
  h2('6. Si algo falla'),
  ul(
    '**Sin conexión:** reconectate y continuá la partida si sigue vigente. Las respuestas y los puntos oficiales requieren conexión.',
    '**Salir:** usá **Volver a la expo** o el botón Atrás. Una partida en curso consume un intento y puede reanudarse dentro del plazo.',
    '**Enlace que no abre la app:** pedí un correo nuevo y abrilo en el mismo celular.',
    'Si el resultado no se guardó, aparece **REINTENTAR GUARDADO**: tocalo con conexión.'
  )
]

export const manualAdmins = [
  h1('Manual para administradores'),
  p('Guía breve para preparar, operar y cerrar el evento de expo.'),
  h2('1. Acceso'),
  ol(
    'Ingresá con una cuenta autorizada como administradora y abrí `/#/admin`.',
    'El panel verifica `es_admin()` en la base de datos. Ocultar una ruta no reemplaza los permisos de PostgreSQL/RLS: una cuenta común es rechazada aunque fuerce la URL.',
    'El rol se asigna solo desde el SQL Editor del proyecto (tabla `admin_roles`). Nunca compartas contraseñas, claves de Supabase ni keystores.'
  ),
  h2('2. Preparar el contenido'),
  ol(
    'Usá las pestañas **Eventos**, **Desafíos**, **Preguntas de desafíos**, **Opciones** y **Soluciones**.',
    'Revisá orden, fechas, puntaje, duración, intentos, tolerancia y la solución correcta de cada pregunta.',
    'Mantené el evento y los desafíos en **Borrador** mientras se preparan.',
    'No se publica un desafío sin preguntas ni solución válida (validación del servidor).',
    'No edites reglas de un desafío mientras haya partidas en curso: cada partida conserva su copia de reglas y preguntas.'
  ),
  h2('3. Antes de la expo'),
  ul(
    'Cambiá el evento a **Publicado**.',
    'Verificá el evento desde un navegador sin sesión.',
    'Hacé una partida de ensayo con el desafío de prueba y confirmá que el ranking se actualiza.',
    'Abrí `/#/ranking/<id del evento>` en la pantalla de la expo.',
    'No borres partidas para corregir ensayos: el historial es deliberado.'
  ),
  h2('4. Durante la expo'),
  ul(
    'Controlá el ranking público: debe mostrar solo posición, alias y puntaje.',
    'Si la pantalla pierde conexión, mostrará un aviso; al volver, tocá **Actualizar**.',
    'Ante un problema de red del proyecto, no cambies datos a mano: anotalo en el registro de problemas.'
  ),
  h2('5. Cierre del evento'),
  ol(
    'Cambiá el estado del evento a **Cerrado**: se revelan soluciones y explicaciones y no entran partidas nuevas.',
    'Verificá el ranking final contra la lista de alias anunciada.',
    'Exportá resultados y contenido sin secretos (`supabase db dump --data-only --schema public`) y guardá el respaldo fuera del repositorio.',
    'Dá de baja de forma lógica las cuentas de prueba que corresponda; no borres historial.',
    'Registrá problemas y mejoras para la próxima versión.'
  ),
  h2('6. Recuperación ante una falla'),
  p(
    'Creá un proyecto vacío, aplicá `supabase/migrations/*.sql` en orden, cargá el contenido validado, reasigná `admin_roles` y verificá RLS, Realtime y el UUID del evento. Repetí las pruebas de aceptación antes de reabrir el ranking.'
  )
]
