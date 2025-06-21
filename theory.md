# Crédito Garantizado

## Supuestos

- El interés se determina al inicio del contrato financiero y la tasa se mantiene fija hasta la terminación del contrato.
- El interés se calcula con una tasa continua del tipo `$e^{rt}$`.
- El horizonte temporal del contrato es `$T = 1$` año.
- Existe liquidez perfecta en el mercado.
- Los costos de transacción son cero.
- No hay repago voluntario anticipado; el contrato solo termina por vencimiento o liquidación.
- Toda la deuda se coloca al 100%. (Existe siempre market maker)

## Mercado: USDC / ETH

### Caso 1: Se solicita USDC depositando ETH como colateral

- **El prestamista:** Aporta `USDC` y espera recibir `USDC + interés`.
- **El prestatario:** Aporta `ETH` como colateral y se compromete a pagar `USDC + interés` para recuperar su `ETH`.

---

### Desarrollo del Caso del Prestatario (Alice)

Analicemos el caso de Alice, quien posee `1 ETH` y necesita `1000 USDC`.

- **Precio inicial:** `1 ETH = 2000 USDC`
- **Tasa de interés anual (r):** `10%` o `$r = 0.1$`

Alice tiene dos opciones principales:

1. **Vender:** Puede vender `0.5 ETH` en el mercado para obtener los `1000 USDC` que necesita. Se quedaría con `0.5 ETH` y `1000 USDC`.
2. **Pedir un préstamo:** Puede usar su `ETH` como colateral para pedir un préstamo en `USDC` y pagar intereses.

Exploremos la segunda opción, que es el foco de este análisis.

#### **Situación en t=0 (Inicio del Contrato)**

Para entender el impacto del préstamo, es crucial definir claramente los activos, pasivos y el patrimonio neto de Alice antes y después de la operación.

- **Antes del préstamo:**
- **Activos:** `1 ETH = 2000 USDC`
- **Pasivos:** `0 USDC`
- **Patrimonio Neto:** `2000 USDC`

Alice decide tomar un préstamo de `1000 USDC` usando su `ETH` como colateral.

- **Inmediatamente después del préstamo (t=0):**
- **Activos:** `1 ETH (colateral) + 1000 USDC (efectivo recibido) = 2000 + 1000 = 3000 USDC`
- **Pasivos:** `1000 USDC (deuda)`
- **Patrimonio Neto:** `Activos - Pasivos = 3000 - 1000 = 2000 USDC`

Como se observa, el patrimonio neto de Alice no cambia en el momento de recibir el préstamo. Simplemente ha cambiado la composición de su portafolio.

#### **Situación en t=1 (Vencimiento del Contrato)**

En `t=1`, han ocurrido dos cosas:

1. El interés de la deuda se ha devengado.
2. El precio del colateral (`ETH`) ha cambiado.

Según el supuesto de interés continuo ($e^{rt}$), el valor final de la deuda ($D_1$) es:

$D_1​= D0​⋅e^{rt}=1000⋅e^{0.1⋅1}≈ 1000⋅1.10517 = 1105.17 USDC$

El interés devengado es de **$105.17 USDC**. Ahora, analicemos los dos escenarios de evolución de precios. Para medir el resultado, calculamos el valor final del portafolio de Alice.

> Nota sobre el cálculo del portafolio: La forma más clara de verlo es:
> 
> Valor del Portafolio = (Valor del Colateral - Valor de la Deuda) + Efectivo Obtenido del Préstamo

**Escenario A: El precio de ETH aumenta a 3000 USDC/ETH**

El préstamo está sobrecolateralizado.

- **Valor del Colateral:** `1 ETH = 3000 USDC`
- **Valor de la Deuda:** `1105.17 USDC`
- **Valor final del Portafolio:** `VP = (3000 - 1105.17) + 1000 = 1894.83 + 1000 = 2894.83 USDC`

El patrimonio neto inicial era de `2000 USDC`. El cambio neto es `+894.83 USDC`. Esto se explica porque su `ETH` ganó `1000 USDC` de valor, y el costo del financiamiento fue de `105.17 USDC` (`1000 - 105.17 = 894.83`).

**Escenario B: El precio de ETH disminuye a 1000 USDC/ETH**

La deuda supera el valor del colateral, resultando en un préstamo subcolateralizado.

- **Valor del Colateral:** `1 ETH = 1000 USDC`
- **Valor de la Deuda:** `1105.17 USDC`
- **Valor final del Portafolio:** `VP = (1000 - 1105.17) + 1000 = -105.17 + 1000 = 894.83 USDC`

El patrimonio neto inicial era `2000 USDC`. El cambio neto es `-1105.17 USDC`. Esto se debe a que su `ETH` perdió `1000 USDC` de valor y, además, incurrió en un costo de financiamiento de `105.17 USDC`.

---

### El Punto de Liquidación

El escenario B nos lleva a una pregunta crucial: **¿Qué sucede cuando el valor del colateral es menor que la deuda?**

La respuesta depende del diseño del protocolo financiero. En un entorno DeFi, para proteger al prestamista, el colateral se habría liquidado _antes_ de que el préstamo quedara subcolateralizado ("bajo el agua").

Pensemos en las funciones de valor:

- **Valor de la Deuda (Dt​):** Es una función determinista que crece exponencialmente con el tiempo. El principal es `$D_0$`. $D_t​= D_0​⋅e^{rt}$
- **Valor del Colateral (Ct​):** Es un proceso estocástico, ya que depende del precio de mercado del activo, `$P_t$`. $C_t​= Q⋅P_t​ Donde `$Q$` es la cantidad de colateral (ej. 1 ETH) y `$P_t$` es el precio (ej. `USDC/ETH`).

Por definición, al inicio del contrato en `t=0`, el colateral es mayor que la deuda: `$C_0 > D_0$`.

#### **Criterio de Liquidación**

**Idea 1: Liquidar cuando `$C_t = D_t$`**

- **Intuición:** Este es el último momento en el que el prestamista puede recuperar su capital y los intereses devengados hasta ese instante, sin sufrir pérdidas. Si se espera más y el precio del colateral sigue cayendo, el prestamista perderá dinero.
    
- **Visualización:**
  
      > **[Insertar gráfico aquí]**
      > - **Eje Y:** Valor en USDC
      > - **Eje X:** Tiempo (desde `t=0` hasta `T=1`)
      > - **Curva de la Deuda:** Una función exponencial creciente, que parte de `$D_0$` y termina en `$D_0 \cdot e^{rT}$`.
      > - **Curva del Colateral:** Un camino aleatorio (proceso estocástico) que parte de `$C_0$`. La liquidación se activa si `$C_t$` intersecta a `$D_t$`.                          

#### **Consecuencias Financieras de una Liquidación Anticipada**

1. **Para el prestamista:** Implica la preservación del capital y de los intereses devengados hasta ese momento (asumiendo liquidez perfecta). Aunque no obtiene la ganancia total esperada del préstamo, evita una pérdida.
2. **Para el prestatario:** Significa la pérdida total de su colateral.

---

### Funciones de Pago, Similitudes con Derivados, Option Pricing.

Vamos a examinar las funciones de pago para cada participante.

La condición de liquidación (`el primero de t=T o C_t = D_t`) introduce **dependencia de la trayectoria** (path dependency). El resultado final ya no depende solo del precio del colateral en la fecha de vencimiento, sino de si el precio del colateral ha tocado un "nivel barrera" en algún momento durante la vida del préstamo.

Este "nivel barrera" (`$H_t$`) no es fijo, sino que se mueve en el tiempo: es el valor creciente de la deuda, `$H_t = D_t = D_0e^{rt}$`.

Así es como afecta a las funciones de pago y a las analogías con derivados:

---

### 1. Para el Prestatario (Alice)

**Opción Call de Barrera Descendente (Down-and-Out Call)**.
- **Activo Subyacente:** El colateral (`ETH`).
- **Precio de Ejercicio (Strike):** `$D_T$`.
- **Barrera (`H_t`):** El valor de la deuda, `$D_t$`. Es una barrera móvil y ascendente.
- **Condición "Out":** La opción queda sin valor si el precio del subyacente cae y toca la barrera.

La cláusula de liquidación añade una condición fatal para la opción de Alice: si el valor de su colateral $C_t$ cae y toca la barrera creciente de la deuda $D_t$, su opción es "noqueada" (knocked out) y deja de existir.

- **Si la barrera NUNCA se toca (`$C_t > D_t$` para todo `$t < T$`):** La opción sobrevive hasta el vencimiento y su payoff sigue siendo `$\max(0, C_T - D_T)$`.
- **Si la barrera SÍ se toca en un momento `$t_{liq} < T$`:** El colateral se liquida. La opción de Alice se extingue inmediatamente y su valor se convierte en cero. Pierde todo el valor tiempo que le quedaba a la opción y la posibilidad de que el colateral se recuperara.

---

### 2. Para el Prestamista

**Opción Put de Barrera Descendente (Down-and-Out Put)**. El prestamista vendió una put que se desactiva justo cuando empezaría a ser más peligrosa para él.

**En resumen, la función del prestamista se asemeja a:**

- Poseer un bono libre de riesgo que paga `$D_T$`.
- Haber vendido una Opción Put "Down-and-Out", que es mucho menos riesgosa que una put normal.

La cláusula de liquidación es un mecanismo de gestión de riesgo fundamental para el prestamista. Actúa como un "stop-loss" dinámico que protege su capital.

- **Si la barrera NUNCA se toca:** El payoff no cambia. Recibe `$D_T$` al vencimiento, ya que el prestatario pagará la deuda.
- **Si la barrera SÍ se toca en `$t_{liq} < T$`:** El contrato se termina. El prestamista recibe el colateral, cuyo valor es exactamente igual al de la deuda en ese momento (`$C_{t_{liq}} = D_{t_{liq}}$`).

---

### Tabla Comparativa de Estrategias

| **Participante** | **Posición Sin Liquidación (Derivado Europeo)** | **Posición Con Liquidación (Derivado de Barrera)** | **Efecto Principal de la Liquidación**                                                                                 |
| ---------------- | ----------------------------------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Prestatario**  | **Long Call**                                   | **Long Down-and-Out Call** (con barrera móvil)     | **Reduce el valor.** Se pierde la opcionalidad si el colateral tiene una caída temporal.                               |
| **Prestamista**  | **Bono + Short Put**                            | **Bono + Short Down-and-Out Put**                  | **Reduce el riesgo.** Actúa como un stop-loss, protegiendo el capital del prestamista de caídas severas del colateral. |

En conclusión, la función de liquidación es el mecanismo que hace que el acuerdo sea viable. El prestatario cede valor (al aceptar la condición de "knock-out") y el prestamista gana seguridad (al limitar su riesgo a la baja). Esta transferencia de riesgo y valor es el corazón del contrato de crédito garantizado.

---

#### Nota Aclaratoria

(1) Si `USDC/ETH` se trata como una variable aleatoria continua, la probabilidad de que tome cualquier valor exacto es 0. Esto es una simplificación teórica; en la práctica, los precios son discretos debido a los límites de decimales en los sistemas de trading, por lo que la probabilidad no es estrictamente cero, pero sí muy pequeña para un valor específico.
