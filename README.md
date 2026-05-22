# md5eval

**A RESTful API to validate JSON files using a deterministic MD5 algorithm**\
**Una API RESTful para validar archivos JSON utilizando un algoritmo MD5 deterministico**

Una vez preparado localmente el archivo Docker container en el localhost...

## 1. Despliegue y Stop (Deployment & Teardown)

Para "compilar" e iniciar el script completo (FastAPI + Nginx reverse proxy):
```bash
$ ./build.sh
$ ./start.sh
```
Para detener el entorno y liberar los recursos del sistema:
```bash
$ ./stop.sh
```

## 2. Ejemplos de Uso (Valid & Invalid Request Examples)
#### Dado que el entorno completo corre hardened y aislado dentro de Docker, las peticiones deben apuntar al puerto estándar `80` gestionado por el reverse proxy de Nginx, el cual redirige el trafico internamente. Asegurarse de no tener otro Nginx corriendo.

### Ejemplos de Uso (API REST)

#### Ejemplo del clonado del git, y su funcionamiento...
```bash
$ git clone https://github.com/leokasion/md5eval.git

Cloning into 'md5eval'...
remote: Enumerating objects: 58, done.
remote: Counting objects: 100% (58/58), done.
remote: Compressing objects: 100% (40/40), done.
remote: Total 58 (delta 25), reused 36 (delta 10), pack-reused 0 (from 0)
Receiving objects: 100% (58/58), 15.90 KiB | 15.90 MiB/s, done.
Resolving deltas: 100% (25/25), done.
$ sudo docker-compose build #aqui utilizo `sudo` por que solo quiero probar el script en mi localhost

[sudo] password for okasion:           
nginx uses an image, skipping
Building api
Sending build context to Docker daemon  100.9kB
Step 1/15 : FROM python:3.11-slim AS builder
3.11-slim: Pulling from library/python
5b4d6ff92fc4: Pull complete 
8649771fee17: Pull complete 
797d495f2c68: Pull complete 
45006ceeeea9: Pull complete 
Digest: sha256:a3ab0b966bc4e91546a033e22093cb840908979487a9fc0e6e38295747e49ac0
Status: Downloaded newer image for python:3.11-slim
 ---> 1455a91ef4da
Step 2/15 : WORKDIR /app
 ---> Running in 9cde03ac1a4f
Removing intermediate container 9cde03ac1a4f
 ---> 1b406671a1a0
Step 3/15 : RUN  python -m venv /opt/venv
 ---> Running in 3c3f83617c06
Removing intermediate container 3c3f83617c06
 ---> d431815b61ca
Step 4/15 : ENV PATH="/opt/venv/bin:$PATH"
 ---> Running in a36333c3debd
Removing intermediate container a36333c3debd
 ---> 9df6a0bcadb9
Step 5/15 : COPY requirements.txt .
 ---> 19175316e5b1
Step 6/15 : RUN pip install --no-cache-dir -r requirements.txt
 ---> Running in 4e49e9491e75
Collecting fastapi==0.136.1 (from -r requirements.txt (line 1))
...
...
...

$ sudo docker-compose up -d
md5eval_api_1 is up-to-date
Starting md5eval_nginx_1 ... done

$ curl -i -X GET http://localhost/health
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 22 May 2026 12:17:09 GMT
Content-Type: application/json
Content-Length: 15
Connection: keep-alive

{"status":"ok"}

$ curl -i -X POST http://localhost/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 200 OK
Server: nginx
Date: Fri, 22 May 2026 12:18:04 GMT
Content-Type: application/json
Content-Length: 59
Connection: keep-alive
{"status":"success","message":"Payload integrity verified"}
```

### Ejemplos de la devolucion de datos del servidor...
#### Health check (GET 200 OK)
```bash
$ curl -i -X GET http://localhost/health 
HTTP/1.1 200 OK
date: Thu, 21 May 2026 18:39:10 GMT
server: nginx
content-length: 15
content-type: application/json
```

#### Request Valido (POST 200 OK)
```bash
$ curl -i -X POST http://localhost/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 200 OK
date: Fri, 22 May 2026 10:19:44 GMT
server: nginx
content-length: 59
content-type: application/json

{"status":"success","message":"Payload integrity verified"}
```

#### Request Invalido (POST 400 Bad Request)

Si se modifica temporalmente cualquier valor dentro de test_payload.json sin actualizar correspondientemente el campo "md5" dentro del JSON, la API rechazará el procesamiento:
```bash
$ curl -i -X POST http://localhost/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 400 Bad Request
date: Thu, 21 May 2026 19:09:38 GMT
server: nginx
content-length: 70
content-type: application/json

{"detail":"MD5 mismatch. Calculated f626dbf09335fc1c960a41c5f55a3d2b"}
```

## 3. Decisiones Tecnicas y Calculo del MD5

### Estrategia de Canonicalizacion Criptografica
Para cumplir con el requerimiento de validar de forma exacta y deterministica el contenido enviado sin importar como el cliente altere el formato del archivo JSON (espacios, saltos de línea o identacion), se implemento una estrategia alineada estrictamente con el estandar internacional **RFC 8785 (JSON Canonicalization Scheme / JCS)**.
De acuerdo a la especificacion oficial del estandar:
* **Seccion 3.2.3 (Mapping Rules - Object):** Dictamina que *"The property members of an object MUST be sorted lexicographically by their property name strings, based on UTF-16 code units"* (Las propiedades deben ordenarse alfabeticamente). Esto se garantiza en el backend mediante el uso de `sort_keys=True` al serializar el payload.
* **Sección 3.2.1 (Whitespace):** Determina de forma tajante que *"Whitespace MUST NOT be generated"* (No se deben generar espacios en blanco). Esto se mapea en nuestro codigo utilizando separadores compactos (`separators=(',', ':')`) para purgar cualquier formateo o indentación del cliente.

* Pense mucho en hacer este script con Golang para comparar bit por bit, en vez de Python; de hecho comence a trabajar con el primero, pero me di cuenta a medida que armaba el "esqueleto" y la cantidad de lineas de codigo crecian, que quizas estaria corto de tiempo, sobre todo al tener que hacerlo pasar por el pipeline de GitHub Actions, que todavia tiene problemas con Go. Esta fue la razon por la que decidi utilizar Python y estoy adviertiendo sobre ordenar alfabeticamente los bloques de JSON antes de compararlos criptograficamente via MD5, por que si bien:\
{ "a": 1, "b": 2 } == { "b": 2, "a": 1 } para el uso cotidiano de lectura en JSON, no representan lo mismo para el resultado binario del hash MD5.

1. **Parseo y Modelado Estricto:** El payload entrante es interceptado y validado en su estructura mediante **Pydantic v2** (`ValidationRequest`).
2. **Aislamiento de la Firma (Separacion de Incumbencias):** Antes de calcular el hash, convertimos el modelo en un diccionario nativo y removemos el campo `"md5"` utilizando `data_dict.pop("md5", None)`. Esto es fundamental para evitar un bucle de dependencia mutua (donde cambiar el valor del hash alteraría el resultado del hash mismo).
3. **Serializacion Determinista:** El diccionario restante (con los campos `date`, `status`, `id`, `name`, `metadata`) se serializa a texto plano usando
   `json.dumps(data_dict, sort_keys=True, separators=(',', ':'))`. 
   * `sort_keys=True` fuerza un ordenamiento alfabetico estricto de las claves.
   * `separators=(',', ':')` elimina cualquier espacio en blanco remanente de la estructura tipografica.
5. **Hashing:** La cadena resultante y compactada se codifica en `utf-8` y se procesa con la librería nativa `hashlib.md5` para su posterior comparación con la firma enviada por el cliente.

### Justificación de Componentes
* **FastAPI + Uvicorn:** Elegido por su alto rendimiento asincronico nativo y la velocidad de validacion de esquemas que provee Pydantic en la capa de datos, sumado a que el ejercicio asi lo requiere. Si bien estoy mas familiarizado con Flask, no tuve problema con OpenAPI asi que no me puedo quejar; con respecto al webserver, el de Flask se llama Gunicorn (Green Unicorn). El mundo de Python esta lleno de extrañas creaturas.  
* **Nginx Reverse Proxy (Fase de Contenedores):** Requerido para "soltar" el servidor de aplicaciones de la exposicion directa a la red, gestionando la terminación del trafico en el puerto estandar 80 y mapeando internamente el mismo hacia el puerto 8000 del contenedor de FastAPI de forma transparente.

## 4. Supuestos, Riesgos y Consideraciones para Produccion

### Plan de Ajustes para Entornos Productivos de Escala Enterprise
Si esta solución requiriera migrar hacia un cluster, se aplicarían los siguientes cambios operativos:

* **Manejo de Secrets:** Migrar cualquier configuracion en texto plano hacia un inyector dinamico de variables de entorno en tiempo de ejecución. En entornos de Kubernetes, esto se resolvera "desacoplando" las credenciales mediante objetos nativos `kind: Secret` referenciados en los archivos de despliegue (los archivos YAML), o integrando un proveedor externo centralizado como **AWS Secrets Manager** para cargas de trabajo críticas de produccion, evitando exponer datos sensibles en el historial de comandos o archivos de configuración.
* **Observabilidad (Logs y Metricas):** En una infraestructura de produccion real, se puede integrar el flujo de logs hacia un stack centralizado de telemetría (**Grafana Loki** o **ELK Stack**), junto con un exportador de metricas de Prometheus para generar alertas basadas en tasas de error 5xx o latencias atípicas. Esto seria una exageracion para un script tan pequeño, pero vale la pena mencionarlo.
* **Seguridad y Escaneo:** Integracion en la pipeline de CI/CD de herramientas de escaneo de vulnerabilidades estáticas (con **Trivy** o **Snyk**) tanto para las dependencias de Python en el entorno virtual como para las capas base de la imagen en el Dockerfile.*
* **Registro y Versionado:** Almacenamiento y firmado criptografico de imágenes Docker en un registro seguro (como **AWS ECR**), tagueando rigurosamente cada build mediante el hash corto de Git (`SHA`), prohibiendo terminantemente el uso del tag genérico `latest`.

## 5. Troubleshooting 

#### Error: `unknown flag: --no-cache` o fallos en `docker compose`
Si al ejecutar `./build.sh` la terminal devuelve un error de sintaxis indicando que no reconoce flags o comandos, se debe a una discrepancia de versiones en el motor de Docker local (motores como el que viene con mi distribucion, antiguos que no soportan la sintaxis nativa de plugins V2 `docker compose` con espacio -pero no creo que este sea su caso).

**Solución rapida:**
Modificar los scripts wrapper (`build.sh`, `start.sh`, `stop.sh`) para utilizar la sintaxis con guion medio (`docker-compose`). Por ejemplo, en `build.sh`:

```bash
# Cambiar esto:
docker compose build --no-cache

# Por esto (compatibilidad con Docker Compose v1 / Motores antiguos):
docker-compose build --no-cache
```
