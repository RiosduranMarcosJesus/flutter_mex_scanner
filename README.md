# 🇲🇽 Flutter MEX Scanner

Aplicación desarrollada en **Flutter** para la **extracción automatizada de datos (OCR)** desde documentos oficiales mexicanos como **CURP** e **INE**.

El sistema está diseñado para **automatizar la captura de información personal** a partir de documentos físicos o digitales, reduciendo errores humanos y acelerando procesos administrativos, bajo un enfoque **privacy-first** donde los datos se procesan exclusivamente en el dispositivo.

---

# 🛡️ Privacidad y Seguridad

La aplicación maneja **información personal sensible (PII)**, por lo que implementa un modelo de seguridad basado en **procesamiento local y cero persistencia de datos**.

- **Procesamiento local:** todo el OCR se ejecuta directamente en el dispositivo.
- **Sin almacenamiento:** los datos extraídos no se guardan en bases de datos ni archivos locales.
- **Sin transmisión:** la aplicación no envía información a servidores externos.

La información solo existe **temporalmente en memoria** durante el proceso de análisis.

---

# 🧰 Stack Tecnológico

| Tecnología | Uso |
|---|---|
Flutter | Desarrollo de la aplicación |
Dart | Lenguaje principal |
Google ML Kit | Motor OCR on-device |
Local Auth | Autenticación biométrica |
Regex | Validación estructural de datos |

---

# 🏗️ Arquitectura

El proyecto sigue un enfoque combinado de:

- **Feature-First Architecture**
- **Clean Architecture**

Principios aplicados:

- SOLID  
- Alta cohesión  
- Bajo acoplamiento  
- Separación clara de responsabilidades

---

# 🚀 Funcionalidades

### Reconocimiento de documentos
Extracción automatizada de información desde:

- **CURP**
- **INE**

Campos identificados:

- Nombre completo  
- CURP  
- Fecha de nacimiento  
- Sexo  
- Entidad federativa  

### Seguridad biométrica
Acceso protegido mediante autenticación biométrica del dispositivo:

- Huella dactilar  
- FaceID  
- Biometría del sistema  

### Validación de datos
El sistema valida automáticamente los datos detectados utilizando **expresiones regulares (Regex)** para verificar la estructura oficial de:

- CURP  
- RFC  

Esto permite detectar y corregir errores comunes del OCR.

### Entrada de documentos
El sistema puede procesar documentos desde:

- Cámara  
- Imágenes de galería  
- Archivos PDF  

---

# 📌 Estado del Proyecto

**En desarrollo**

Implementado:

- OCR de CURP  
- Validación estructural de datos  
- Procesamiento local  

En progreso:

- OCR desde PDF  
- Soporte completo para INE  
- Optimización del motor de extracción  

---

# 👨‍💻 Autor

**Marcos Jesús Rios Duran** /[@Marcos-Jesús-Ríos-Durán](https://github.com/Marcos-Jesus-Rios-Duran)

Intereses técnicos:

- Flutter  
- Arquitectura de software  
- Seguridad de datos  
- Computer Vision
