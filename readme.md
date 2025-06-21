# DebtHook: Un Protocolo de Lending MVP en Uniswap v4

## Descripción General

**DebtHook** es un protocolo de préstamos descentralizado y sin custodia construido como un **Hook de Uniswap v4**. Permite a los usuarios tomar préstamos a plazo y tasa fijos en `USDC`, utilizando `ETH` como colateral.

El objetivo de este proyecto es demostrar un modelo de deuda puro, donde las interacciones de préstamo y liquidación se gestionan a través de un contrato Hook que utiliza un pool de Uniswap v4 como una capa de liquidación de capital eficiente.

##  Estado del Proyecto: MVP (Producto Mínimo Viable)

⚠️ **ADVERTENCIA:** Esta implementación es una **Prueba de Concepto (Proof of Concept)**. Su propósito es validar la arquitectura y la lógica fundamental del modelo teórico. **NO ESTÁ LISTO PARA PRODUCCIÓN** y carece de muchas de las optimizaciones, características de seguridad y mecanismos de mitigación de riesgos necesarios para manejar fondos reales. **Úselo únicamente con fines educativos y de prueba.**

## Decisiones de Diseño para la Simplificación (MVP)

Para lograr un prototipo funcional y enfocarnos en la mecánica central, se tomaron las siguientes decisiones de diseño que simplifican la implementación:

### 1. Mercado Único (`USDC/ETH`)

* **Decisión:** El protocolo solo soporta préstamos de `USDC` colateralizados con `ETH`.
* **Razón de Simplificación:** Limitar el sistema a un único par de activos de alta liquidez elimina una enorme complejidad. Evita la necesidad de gestionar múltiples oráculos de precios, diferentes parámetros de riesgo por activo (LTV, umbrales de liquidación), y la lógica para manejar una variedad de tokens con distintos decimales o características (ej. rebasing tokens).

### 2. Liquidación Total

* **Decisión:** Cuando un préstamo se vuelve elegible para liquidación (el valor del colateral es menor o igual a la deuda), el 100% del colateral se vende.
* **Razón de Simplificación:** La lógica para una liquidación total es binaria y directa. Esto hace que se pueda interpretar como un derivado, aunque exótico, convencional. Ver el paper "theory" para leer mas de los derivados sintéticos que asemeja.

### 3. Tasas de Interés Fijas

* **Decisión:** La tasa de interés de un préstamo se establece en el momento de su creación y permanece constante durante toda su vida.
* **Razón de Simplificación:** Esto hace que el cálculo de la deuda pendiente (`$D_t = D_0 \cdot e^{rt}$`) sea predecible y fácil de calcular. Además, permite que se realize "price discovery" orgánicamente en el mercado de deuda, que es además un objetivo del protocolo: Tener una fuente nativa para calcular el "yield curve" implícito entre USDC y ETH.

### 4. Posiciones Intransferibles (No son NFTs)

* **Decisión:** Las posiciones de deuda (tanto del prestamista como del prestatario) son intransferibles y están vinculadas a las direcciones originales. No se emiten tokens ERC-721 para representarlas.
* **Razón de Simplificación:** Al mantener las posiciones como simples entradas en un `mapping` dentro del contrato, nos enfocamos exclusivamente en la funcionalidad de préstamo y liquidación.

### 5. Sin Fondo de Seguros (Riesgo Asumido por el Prestamista)

* **Decisión:** El protocolo no implementa un módulo de seguridad, tesorería o fondo de seguros para cubrir las "deudas malas" que puedan surgir. 
* **Razón de Simplificación:** El riesgo de liquidez es uno de los principales drivers de tasas de interés en este mercado. En este MVP, el riesgo de una liquidación fallida (donde el `USDC` obtenido es menor que la deuda debido a slippage o un crash del mercado) es **asumido en su totalidad por el prestamista**. Esto presenta un modelo de riesgo puro.

## Arquitectura Central

El sistema se compone de tres elementos principales:

1.  **`DebtHook.sol`**: El contrato inteligente principal que hereda de `BaseHook`. Actúa como el gestor de posiciones de deuda, custodia el colateral y contiene toda la lógica para crear, repagar y liquidar préstamos.
2.  **Pool de Uniswap v4 (`USDC/ETH`)**: No se utiliza por sus hooks, sino como una **infraestructura de liquidación pasiva**. El `DebtHook` lo invoca para ejecutar swaps durante las liquidaciones.
3.  **Dependencias Externas**:
    * **Oráculo de Precios (Chainlink)**: Para obtener de forma fiable el valor en tiempo real del colateral (`ETH`).
    * **[NO IMPLEMENTADO] Keepers (Bots)**: Actores externos automatizados que son necesarios para monitorear el estado de los préstamos y llamar a la función `liquidate()` cuando una posición se vuelve insolvente. Por el momento, esa función debe ser llamada por la contraparte que prestó el dinero.

## Fundamento Teórico (agregar link a theory)

Este protocolo es la implementación práctica de un modelo financiero donde:
- La posición del **Prestatario** es equivalente a una **Opción Call Larga** sobre su colateral.
- La posición del **Prestamista** es equivalente a un **Bono + una Opción Put Corta**.
- La **función de liquidación** es equivalente a una **Barrera dinámica**, es el mecanismo de ejecución que asegura el cumplimiento de los términos del contrato cuando el valor del colateral (`$C_t$`) alcanza el de la deuda (`$D_t$`).

## Riesgos y Próximos Pasos

Como MVP, los principales riesgos radican en las dependencias y simplificaciones:
- **Riesgo del Oráculo:** El sistema es tan seguro como su feed de precios.
- **Riesgo de los Keepers:** El protocolo depende de la acción oportuna y racional de los keepers.
- **Riesgo de MEV:** Las liquidaciones son vulnerables a ser explotadas por MEV.

Los próximos pasos para evolucionar más allá del MVP incluirían:
- Soportar múltiples mercados y colaterales.
- Tener un TWAP oracle de Uniswap?? Hay que explorar la idea.

---
# WIP // No detallado:

- Cómo se conecta con el front end? Cómo funciona el B2B orderbook?

# Veremos si se implementa:
- Pagar gas con USDC
- Integrar "verificabilidad" de Eigen al B2B orderbook

# Cómo aprovechar los Hooks de v4?
- Hacer Pools Vetados (Solo humanos, por ejemplo)
- Hacer Payback de Fees (La idea es tener mucha liquidez y que la gente la use "regardless", pero tener un payback puede ser clave para nosotros)
- Integrar algo de privacidad para mitigar los ataques MEV
