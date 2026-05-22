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

### Ejemplos de Uso (API REST)
Se recomienda abrir un Uvicorn y dejarlo corriendo en foreground en otra tab en el mismo directorio del script en el caso de que se quiera ver que "devuelve" el mismo en tiempo real:
```bash
$ ./venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### Health check (200 OK)
```bash
$ curl -i -X GET http://localhost:8000/health 
HTTP/1.1 200 OK
date: Thu, 21 May 2026 18:39:10 GMT
server: uvicorn
content-length: 15
content-type: application/json
```

### Request Valido (200 OK)
```bash
$ curl -i -X POST http://127.0.0.1:8000/validate-md5 -H "Content-type: application/json" --data-binary @test_payload.json
HTTP/1.1 200 OK
date: Fri, 22 May 2026 10:19:44 GMT
server: uvicorn
content-length: 59
content-type: application/json

{"status":"success","message":"Payload integrity verified"}
```

### Request Invalido (400 Bad Request - Hash Mismatch)

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
