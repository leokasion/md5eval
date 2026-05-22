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

### Estrategia de Canonicalización Criptográfica
Para cumplir con el requerimiento de validar de forma exacta y deterministica el contenido enviado sin importar como el cliente altere el formato del archivo JSON (espacios, saltos de línea o identacion), se implementó la siguiente logica en el backend:

1. **Parseo y Modelado Estricto:** El payload entrante es interceptado y validado en su estructura mediante **Pydantic v2** (`ValidationRequest`).
2. **Aislamiento de la Firma (Separacion de Incumbencias):** Antes de calcular el hash, convertimos el modelo en un diccionario nativo y removemos el campo `"md5"` utilizando `data_dict.pop("md5", None)`. Esto es fundamental para evitar un bucle de dependencia mutua (donde cambiar el valor del hash alteraría el resultado del hash mismo).
3. **Serializacion Determinista:** El diccionario restante (con los campos `date`, `status`, `id`, `name`, `metadata`) se serializa a texto plano usando `json.dumps(data_dict, sort_keys=True, separators=(',', ':'))`. 
   * `sort_keys=True` fuerza un ordenamiento alfabetico estricto de las claves.
   * `separators=(',', ':')` elimina cualquier espacio en blanco remanente de la estructura tipografica.
4. **Hashing:** La cadena resultante y compactada se codifica en `utf-8` y se procesa con la librería nativa `hashlib.md5` para su posterior comparación con la firma enviada por el cliente.

### Justificación de Componentes
* **FastAPI + Uvicorn:** Elegido por su alto rendimiento asincronico nativo sobre la especificación ASGI y la velocidad de validación de esquemas que provee Pydantic en la capa de datos, sumado a que el ejercicio asi lo requeria. Por mi hubiese utilizado Flask por que estoy mas familiarizado, pero no tuve problema con OpenAPI asi que no me puedo quejar; con respecto al webserver, el de Flask se llama Gunicorn (Green Unicorn). El mundo de Python esta lleno de extrañas creaturas.  
* **Nginx Reverse Proxy (Fase de Contenedores):** Requerido para "desacoplar" el servidor de aplicaciones de la exposición directa a la red, gestionando la terminación del trafico en el puerto estándar 80 y mapeando internamente el upstream hacia el puerto 8000 del contenedor de FastAPI de forma transparente.

---

## 4. Supuestos, Riesgos y Consideraciones para Producción (DevSecOps)

### Supuestos y Limitaciones Actuales
* **Carga en Memoria:** El endpoint asume payloads JSON de tamaño moderado. Al realizar un mapeo de todo el árbol de datos a memoria a través de Pydantic, archivos masivos (en el orden de gigabytes) podrían comprometer los recursos de la arquitectura local si no se limita el tamaño del body en el proxy de entrada.
* **Tipado de Fecha Variable:** El campo `date` está mapeado como un diccionario libre en el modelo base para admitir subestructuras dinámicas complejas (por ejemplo: `year`, `month`, `day`).

### Plan de Ajustes para Entornos Productivos de Escala Enterprise
Si esta solución requiriera migrar hacia un clúster de alta disponibilidad bajo demanda, se aplicarían las siguientes directrices operativas:

* **Despliegue y Rollback:** Implementación de estrategias de despliegue tipo **Blue-Green** o **Canary** mediante manifiestos nativos de Kubernetes (reemplazando Docker Compose) combinados con ArgoCD para GitOps, permitiendo rollbacks instantáneos ante fallos detectados por métricas de error de HTTP.
* **Manejo de Secrets:** Migración de cualquier configuración en texto plano hacia un inyector dinámico de variables de entorno en tiempo de ejecución, utilizando **HashiCorp Vault** o **AWS Secrets Manager**, desacoplando credenciales del código fuente.
* **Observabilidad (Logs y Métricas):** Configuración de un formateador de logging estructurado en formato **JSON estructurado** nativo para la app y Nginx, integrando el flujo de logs hacia un stack centralizado de telemetría (**Grafana Loki** o **ELK Stack**), junto con un exportador de métricas de Prometheus para generar alertas basadas en tasas de error 5xx o latencias atípicas.
* **Seguridad y Escaneo:** Integración en la pipeline de CI/CD de herramientas de escaneo de vulnerabilidades estáticas (SAST con **Trivy** o **Snyk**) tanto para las dependencias de Python en el entorno virtual como para las capas base de la imagen en el Dockerfile.
* **Registry y Versionado:** Almacenamiento y firmado criptográfico de imágenes Docker en un registro seguro (como AWS ECR o Harbor), tagueando rigurosamente cada build mediante el hash corto de Git (`SHA`) o versionado semántico formal (`vX.Y.Z`), prohibiendo terminantemente el uso del tag genérico `latest`.
* **Límites de Recursos:** Definición explícita de límites físicos (`limits`) y reservas bajo demanda
