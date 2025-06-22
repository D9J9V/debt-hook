### **Plan de Desarrollo Detallado para el MVP `DebtHook`**

#### **Fase 1: Desarrollo y Pruebas del Contrato**

**Paso 1: Configuración del Entorno de Desarrollo**
* **Tarea:** Preparar el proyecto local.
* **Detalles:**
    * Configurar el framework de desarrollo (Foundry)
    * Configurar el proyecto, incluyendo las dependencias de Uniswap v4 (`v4-core`, `v4-periphery`) y las interfaces de Chainlink.

**Paso 2: Desarrollar el Contrato `DebtHook.sol`**
* **Tarea:** Codificar la lógica del protocolo siguiendo la estructura que definimos.
* **Detalles:**
    * **2.1. Estructura de Datos:** Definir la `struct Loan` y las variables de estado (`mapping(bytes32 => Loan)`, etc.).
    * **2.2. Lógica de Creación:** Implementar `createLoan()`, manejando la recepción de colateral (`msg.value`) y la transferencia del principal `USDC` desde el prestamista.
    * **2.3. Lógica de Repago:** Implementar `repayLoan()`, asegurando que solo el prestatario pueda llamar a la función y que el colateral se devuelva correctamente.
    * **2.4. Cálculo de Deuda:** Implementar la función interna `_calculateCurrentDebt()`. Para el MVP, podrías usar una aproximación lineal del interés compuesto para evitar la complejidad de la exponenciación en Solidity, o usar una librería de matemáticas de punto fijo.
    * **2.5. Lógica de Liquidación:** Implementar `liquidate()`. Esta es la función más compleja y debe incluir:
      * La llamada al oráculo de Chainlink (`priceFeed`).
      * La comparación `$C_t \le D_t$`.
      * La llamada a `poolManager.swap(...)` para ejecutar la venta del colateral.
      * La distribución de los fondos (`USDC`) al prestamista y, si hay remanente, al prestatario.

**Paso 3: Desarrollar Pruebas Unitarias y de Integración (Paso Crítico Faltante)**
* **Tarea:** Asegurar la robustez del contrato antes del despliegue.
* **Detalles:**
    * **3.1. Pruebas Unitarias:** Probar cada función de forma aislada. ¿`_calculateCurrentDebt()` devuelve el valor esperado? ¿Falla `repayLoan()` si lo llama alguien que no es el prestatario?
    * **3.2. Pruebas de Integración (Forking):** Usar un fork de una testnet (ej. Sepolia) para simular condiciones reales. Esto te permite probar la interacción de tu `DebtHook` con el `PoolManager` real de Uniswap v4 y un oráculo de Chainlink real, sin desplegar nada aún.
    * **3.3. Simular Escenarios Clave:**
      * **Happy Path:** Crear un préstamo, esperar y pagarlo con éxito.
      * **Liquidación:** Crear un préstamo, manipular (simuladamente) el precio del oráculo para que esté "bajo el agua" y verificar que la liquidación se ejecuta correctamente.
      * **Casos Borde:** Intentar liquidar un préstamo saludable (debe fallar), intentar pagar un préstamo que no es tuyo (debe fallar).

#### **Fase 2: Despliegue y Ecosistema Off-chain**

**Paso 4: Desarrollar Scripts de Despliegue**
* **Tarea:** Crear un script que despliegue y configure todo el entorno on-chain de forma automática.
* **Detalles:**
    * **4.1. Desplegar `DebtHook`:** El script desplegará tu contrato. Para el despliegue a una dirección predecible ("vanity address"), se puede usar la librería `VanityAddressLib.sol` que se encuentra en la documentación de la periferia de v4.
    * **4.2. Crear el Pool:** El script debe llamar a `poolManager.initialize()` para crear un nuevo pool `USDC/ETH`, pasando la dirección del `DebtHook` y los `hookFlags` correspondientes (que en nuestro caso serían cero, ya que no usamos los hooks de swap).
    * **4.3. Proveer Liquidez Inicial:** El mismo script debe añadir liquidez inicial al pool recién creado para asegurar que los swaps de liquidación puedan ejecutarse.

**[VEREMOS SI PUEDE SER ASÍ] Paso 5: Desarrollar un Keeper Bot Básico (Componente Off-chain Faltante)**
* **Tarea:** Crear el bot que automatizará las liquidaciones.
* **Detalles:**
  * Puede ser un script simple en Node.js (con `ethers.js`) o Python (con `web3.py`).
  * **Lógica del Bot:**
  1.  Escuchar el evento `LoanCreated` para registrar nuevos préstamos.
  2.  Periódicamente (ej. cada minuto), iterar sobre los préstamos activos.
  3.  Para cada préstamo, llamar a una función `view` en tu contrato para verificar su estado de salud (comparar `$C_t` vs `$D_t$`).
  4.  Si un préstamo es elegible para liquidación, construir y enviar una transacción llamando a `liquidate()`.

#### **Fase 3: Interfaz de Usuario y Pruebas Finales**

**Paso 6: Desplegar un Frontend Sencillo**
* **Tarea:** Crear una interfaz de usuario para interactuar con el protocolo.
* **Detalles:**
  * Usar una librería como `wagmi` o `ethers.js` para conectar la UI al blockchain.
  * **Componentes Mínimos:**
  * Botones para `repayLoan()` y `liquidate()` según corresponda.

**Paso 7: Pruebas End-to-End en Testnet**
* **Tarea:** Probar todo el flujo completo en una testnet pública (ej. Sepolia).
* **Detalles:**
  1.  Ejecutar el script de despliegue (Paso 4).
  2.  Poner en marcha el Keeper Bot (Paso 5) para que monitoree los contratos desplegados.
  3.  Usar el Frontend (Paso 6) para crear un préstamo.
  4.  Esperar a que el préstamo se vuelva insolvente (o simularlo si es posible) y verificar que el Keeper lo liquide automáticamente.
  5.  Verificar que los fondos se distribuyan correctamente.
