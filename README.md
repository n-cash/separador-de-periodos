# Separador-de-periodos
## Un separador de períodos dinámico para tradingview, utilizando Pinescript.
> 🦾 El siguiente script fue vibe-codeado utilizando la IA.
>
##### El separador imprime líneas verticales sobre velas específicas, consideradas las aperturas para segmentos predeterminados. Está basado sobre las Ordenes de Magnitud de Elder, donde se perfila la actividad del precio en un conjunto determinado de velas.
-----
## 📊 Funciones del separador.
¿Por qué este separador? Fue creado con la intención de hacer backtesting. Perfilar al eje tiempo en el mercado es una tarea que debería de hacerse manualmente, si lo que se desea es aprender 🧠. Una vez aprendido y entendido, se puede aplicar la misma lógica por ejemplo para crear una herramienta que automatice la tarea. En este caso, lo preparé porque tenía que trasladar mis markups de la estación de backtesting a un nuevo gráfico en tradingview. Haciendo esto me encontré con que este delineado en particular es muy rutinario y apto para scriptearse. Utilizar un script hace más eficiencia de mi tiempo que buscar y manualmente hacer los dibujos, en especial porque...
1. Existen intervalos en los mercados donde las aperturas y cierres se desalinean. Cambios de horario de Invierno a Horario de Verano, Feriados durante el año y particularmente los de final de cada año, y también cosas menos estacionales y más intempestivas que corrompen la simetría del eje tiempo.
2. En un principio intenté usar las Fibonacci Time Zones para extender un día de 24 horas y pintar sus múltiplos cada semana. Esta tarea es muy buena para hacer en backtesting, pero cuando se desea rápidamente volcar todos los datos intradiarios en un gráfico limpio, se vuelve el trabajo acumulado de semanas por hacer. Una tarea muy redundante.
🙏🏻 Esto me lleva a idear un script que con ayuda de la IA pude implementar. Donde la tarea del separador se automatiza.-
-----
## 🎯 ¿Qué hace el script?
Como se dijo, imprime los períodos. Lo hace de manera dinámica, en donde separamos al mercado de distinta manera según la escala en la cual estemos parados (Órdenes de Magnitud de Elder).
### ♦️ Escalas Intradiarias (hasta justo antes de llegar al diario)
- **El script imprime líneas verticales sobre la apertura de cada nuevo día de 24 horas (o 23, o XX, según el caso).** Cada día de la semana sin importar su longitud va a imprimir una línea vertical sobre su apertura.
  - Lo hace separando en grupos distintos lo que es un día lunes, de lo que es el resto de la semana. Así podemos identificar y distinguir en color, estilo, y grosor, las aperturas de cada semana.
  - También crea un tercer grupo para las intradiaras donde se alojan las aperturas de domingo, que pueden encenderse o apagarse, en caso de que se desee no verlas. Esto es para mercados que cierran el fin de semana.
- **A partir del gráfico de 4 horas, las líneas verticales que no sean de Día Lunes (apertura semanal), dejarán de aparecer.** De esta manera se mantiene un gráfico prolijo, sin sobrecargarlo con líneas.
### ♦️ Escala Diaria en adelante.
- **A partir de la escala Diaria, todas las líneas intradiarias dejan de aparecer. En su lugar, veremos líneas verticales de aperturas mensuales y trimestrales.**
  - Mensuales y Trimestrales son nuevamente dos grupos separados distinguibles y configurables.
  - Con un botón de toggle, para poder ver y dejar de ver esta Órden de Magnitud y sus aperturas mientras estemos en temporalidades intradiarias.
- **A medida que incrementamos la escala, las aperturas de menor timeframe dejan de aparecer. Sin embargo al adentrarse en timeframes inferiores, se puede optar por mantener visibilidad sobre las aperturas de mayor escala.**
-----
