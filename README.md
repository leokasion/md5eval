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

#### Ejemplos de Uso (API REST)
Se recomienda abrir un Uvicorn y dejarlo corriendo en foreground en otra tab en el mismo directorio del script en el caso de que se quiera ver que "devuelve" el mismo en tiempo real:
```bash
$ ./venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```
#### _Si se utiliza el entorno de Docker Compose a través de ./start.sh, remover el puerto de los comandos para apuntar directamente al puerto estándar 80 gestionado por Nginx._

### Ejemplos de la devolucion de datos del servidor...
#### Health check (GET 200 OK)
```bash
$ curl -i -X GET http://localhost:8000/health 
HTTP/1.1 200 OK
date: Thu, 21 May 2026 18:39:10 GMT
server: uvicorn
content-length: 15
content-type: application/json
```

#### Request Valido (POST 200 OK)
```bash
$ curl -i -X POST http://127.0.0.1:8000/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 200 OK
date: Fri, 22 May 2026 10:19:44 GMT
server: uvicorn
content-length: 59
content-type: application/json

{"status":"success","message":"Payload integrity verified"}
```

#### Request Invalido (POST 400 Bad Request)

Si se modifica temporalmente cualquier valor dentro de test_payload.json sin actualizar correspondientemente el campo "md5" dentro del JSON, la API rechazará el procesamiento:
```bash
$ curl -i -X POST http://127.0.0.1:8000/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 400 Bad Request
date: Thu, 21 May 2026 19:09:38 GMT
server: uvicorn
content-length: 70
content-type: application/json

{"detail":"MD5 mismatch. Calculated f626dbf09335fc1c960a41c5f55a3d2b"}
```

## 3. Decisiones Tecnicas y Calculo del MD5

### Estrategia de Canonicalizacion Criptografica
Para cumplir con el requerimiento de validar de forma exacta y deterministica el contenido enviado sin importar como el cliente altere el formato del archivo JSON (espacios, saltos de línea o identacion), se implementó la siguiente logica en el backend:

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
* **Seguridad y Escaneo:** Integracion en la pipeline de CI/CD de herramientas de escaneo de vulnerabilidades estáticas (con **Trivy** o **Snyk**) tanto para las dependencias de Python en el entorno virtual como para las capas base de la imagen en el Dockerfile.
* **Registro y Versionado:** Almacenamiento y firmado criptografico de imágenes Docker en un registro seguro (como **AWS ECR**), tagueando rigurosamente cada build mediante el hash corto de Git (`SHA`), prohibiendo terminantemente el uso del tag genérico `latest`.
