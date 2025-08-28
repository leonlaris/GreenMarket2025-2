globals
;; ========================================== ONE WAY GREEN TRANSITION =======================================


;; to EquipmentDecision - Green / Black product with probability 0,5 see procedure code

;; to SetFirms объем выпуска (Qmax через QBE) привязан к фикс затратам месяц Fixed Costs (ACost), произв. мощности обновляются по исчерпании ресурса
;; условие ухода с рынка ProfitCumulative + 12 * Fixed Costs (ACost) < 0
[
 PriceMean

 QD QS QW  QSTotal QSBlack QSBlackTotal  Emission  ;; service variables

 GreenSales BlackSales    ;;  Total sales
 GreenProfit BlackProfit  ;;  Total Profit

 TAXTotal            ;; taxes cumulative amount, exclude ETAX
 TotalCostofCleaning ;; Total Cost of Cleaning
 ETAX                ;; Ecology Taxes per one firm (proportion of one period q-ty produced)
 ETAXTotal           ;; Total Ecology Taxes
 SubsidyTotal        ;; Sum of Subsidies to Firms
 BudgetBalance       ;; Balance
]
;;===========================================================================
breed [products product]
products-own
[
owner
stock
price
cathegory
]
;;===========================================================================
breed [firms firm]
firms-own
[
  ACost      ;; Fixed cost per month
  QBE        ;; Brake-Even quantity
  Qmax       ;; Max quantity

  Qt         ;; produced and offered in M-rule, ONLY produced in M-rule2
  QOff       ;; offered in M-rule2
  QM         ;; sold
  Resource               ;; Total units to produce per the Engine life cycle
  SumForSubsidy          ;; For receiving a Subsidy (if it's possible)

  Profit                 ;; per one tick (month)
  ProfitCumulative       ;; total profit

  GreenTransition  ;; GreenTransition decision (true/false)

  MyProductID      ;; Who of Firm's product
  inmarket         ;; true / false
  Strat            ;; Firm Strategy
]
;;===========================================================================
to setup
  clear-all
  ask patches   [ set pcolor 67 ]

  set p0 1                  ;; 28/08/25
  SetFirms
  ask turtles [ set label-color black ]
  set QD precision (W / p0) 0
  set QS sum [Qt] of firms with [inmarket]

  set QSBlack sum [Qt] of firms with [inmarket and ([cathegory] of product MyProductID) = "Black"]

  set QSTotal 0
  set QSBlackTotal 0
  set TotalCostofCleaning 0
  set SubsidyTotal 0
  set Emission 0
  set ETAXTotal 0
  ;; set p0 1             ;; set as comment 28/08/25

  set GreenSales 0
  set BlackSales 0
  set GreenProfit 0
  set BlackProfit 0

  ask firms with [resource = 0 or Qt = 0] [let LWho who
                                           ask products with [owner = LWho] [die]
                                           die
                                          ]
  output-show "setup done!"           ;; TO OUTPUT AREA AT INTERFACE TAB
  reset-ticks
end
;;===========================================================================
to go

  ;;if (P0 - c1) < 0 or abs (P0 - c1) < 0.005 [output-show "NEGATIVE OR TOO SMALL P0 - C1 VALUE. STOP RUNNING" stop]  ;; 28/08/25

  Production

  ;;;;;; MultiPricesMarket              ;; TEST. INSTEAD  M-rule2


  ;;M-rule  ;; market step
  ;;QS-rule ;; firms decisions after market step

  M-rule2  ;; market step
  QS-rule2 ;; firms decisions after market step

  ;;     ПОКА ЗАКОММЕНТИРОВАНО, СМ ОШИБКУ В ТЕКСТЕ ПРОЦЕДУРЫ ControlParamCorrection  ;; Firms correct control parameters

  ProfitLoss  ;; Profit calculation, Tax payment

  GreenDecision

  EquipmentDecision
  Subsidy?

  if MarketOff [ask firms with [((ProfitCumulative + 12 * ACost) < 0) or Resource = 0]   ;;??????
               [set inmarket false set color red set Resource 0 set Qt 0]]
  ;;  set W precision (random-normal W (0.01 * W)) 0   ;;; demand fluctuation

  Ecology2

  if (Emission >  EmissionCritical and Clean) [Cleaning
                                               if (EcoTAX) [EcologyTAX2]
                                              ]

  set BudgetBalance  TAXTotal +  ETAXTotal - SubsidyTotal - TotalCostofCleaning   ;; Balance

  ;;set GreenProfit sum  [ProfitCumulative] of firms with [inmarket and [cathegory] of product  MyProductID = "Green"]
  ;;set BlackProfit sum  [ProfitCumulative] of firms with [inmarket and [cathegory] of product  MyProductID = "Black"]
  ;; это неправильно, т к это профит фирм, которые в разные моменты времени могли производить разного типа продукты !!!!!!!!!!!

  SHOWLabels
  tick
end
;;===========================================================================
to SetFirms
create-ordered-firms FirmsQty
  [
    set size 2 set shape "person" ;;"building store"

    setxy random-xcor random-ycor
    set color gray ;; green

    FirmsSettings
    set QM 0
    set Profit 0
    set ProfitCumulative 0
    set inmarket true
    set label Qt
  ]
end
;;===========================================================================
to Production
  ask firms with [inmarket]
  [
    set Resource Resource - Qt        ;; NEW 29/06/25
    let L1 who
    let L2 Qt                                                  ;; NEW 01/07/25
    ask products with [owner = L1] [set stock stock + L2]      ;; NEW 01/07/25
    if Resource < 0 [set Resource 0 set inmarket false]        ;; NEW 29/06/25 01/07/25
  ]

  set QSBlack sum [Qt] of firms with [inmarket and ([cathegory] of product MyProductID) = "Black"]      ;; NEW 11/08/25
end
;;=========================================================================== 1st Edition
to M-rule  ;; in the one time frame

  set QD precision (W / p0) 0
  set QS sum [Qt] of firms with [inmarket]
  ask firms [set QM 0]
  ifelse QS <= QD      ;; supply (of firms < Demand (of HH)
    [  ask firms with [inmarket] [set QM Qt
                                  let L1 who                                               ;; NEW 01/07/25
                                  let L2 QM                                                ;; NEW 01/07/25
                                  ask products with [owner = L1] [set stock stock - L2]    ;; NEW 01/07/25
                                 ]
      if any? firms with [inmarket] [set p0 precision (p0 + p0 * dP% / 100) 3]
    ]
    ;; ELSE supply (of firms > Demand (of HH)
    [  set QW 0 ask firms [set QM 0]
    while [QW < QD]
          [ ask firms with [QM = 0 and inmarket]
                           [set QM min list Qt (QD - QW) set QW QW + QM
                            let L1 who                                               ;; NEW 01/07/25
                            let L2 QM                                                ;; NEW 01/07/25
                            ask products with [owner = L1] [set stock stock - L2]    ;; NEW 01/07/25
                           ]
          ]
    if any? firms with [inmarket] [set p0 precision (p0 - p0 * dP% / 100) 3]
    ];;ifelse

end
;;===========================================================================    M-rule2  2nd Edition ==== selling throw products
to M-rule2  ;; in the one time frame NEW 02/07/25

  set QD precision (W / p0) 0
  ask firms with [inmarket] [ let Lwho who
                              set QOff sum [Stock] of products with [owner = Lwho]
                            ]
  set QS sum [QOff] of firms with [inmarket]
  ask firms [set QM 0]
  ifelse QS <= QD      ;; supply (of firms < Demand (of HH)
    [  ask firms with [inmarket] [set QM QOff
                                  let L1 who                                               ;; NEW 02/07/25
                                  let L2 QM                                                ;; NEW 02/07/25
                                  ask products with [owner = L1] [set stock stock - L2]    ;; NEW 02/07/25
                                 ]
      if any? firms with [inmarket] [set p0 precision (p0 + p0 * dP% / 100) 3]
    ]
    ;; ELSE supply (of firms > Demand (of HH)
    [  set QW 0 ask firms [set QM 0]
    while [QW < QD]
          [ ask firms with [QM = 0 and inmarket]
                           [set QM min list QOff (QD - QW) set QW QW + QM
                            let L1 who                                               ;; NEW 02/07/25
                            let L2 QM                                                ;; NEW 02/07/25
                            ask products with [owner = L1] [set stock stock - L2]    ;; NEW 02/07/25
                           ]
          ]
    if any? firms with [inmarket] [set p0 precision (p0 - p0 * dP% / 100) 3]
    ];;ifelse

end
;;========================================================================= QS-rule2

to QS-rule2 ;; after previous market step

  ask firms with [inmarket]
  [ let Corrector 1  ;; For different Firm's Strategies
  (ifelse
    Strat = "A" [set Corrector 1.5]
    Strat = "N" [set Corrector 1]
    Strat = "C" [set Corrector .5]
    ;; elsecommands
   [ show "Error Corrector in QS-rule"])

     let Lwho who
     set QOff sum [Stock] of products with [owner = Lwho]

  ifelse QOff <= QM
   [set Qt  min list (precision (Qt + Corrector * Qt * dQ% / 100) 0)  Qmax
   ]
  ;; ELSE supply (of firms > Demand (of HH)
   [set Qt  max list (precision (Qt / 2) 0) QBe ;;;0
   ]
  ]
end
;;=========================================================================

to QS-rule ;; after previous market step

  ask firms with [inmarket]
  [ let Corrector 1  ;; For different Firm's Strategies
;;  (ifelse
;;    Strat = "A" [set Corrector 2]
;;    Strat = "N" [set Corrector 1]
;;    Strat = "C" [set Corrector .5]
;;    ;; elsecommands
;;    [ show "Error Corrector in QS-rule"])
  ifelse Qt <= QM
   [set Qt  min list (precision (Qt + Corrector * Qt * dQ% / 100) 0)  Qmax
   ]
  ;; ELSE supply (of firms > Demand (of HH)
   [set Qt  max list (precision (Qt - Corrector * Qt * dQ% / 100) 0) 0
   ]
  ]
end
;;============================================================================
to ProfitLoss

  ;;set GreenProfit 0    ;; 4 per Month profit calculation
  ;;set BlackProfit 0

    ask firms with [inmarket]
[ set Profit QM * (p0 - c1) - Acost
    if Profit > 0 [set Profit Profit * (1 - TAX% / 100) set TAXTotal TAXTotal + Profit * (TAX% / 100)]
  set ProfitCumulative precision (ProfitCumulative + Profit) 0

    if [cathegory] of product MyProductID = "Black"            [set BlackProfit BlackProfit + Profit
                                                                set  BlackSales BlackSales + QM * p0
                                                               ]
    if [cathegory] of product MyProductID = "Green"            [set GreenProfit GreenProfit + Profit
                                                                set  GreenSales GreenSales + QM * p0
                                                               ]
    ;; это прибыль 1) без учета ETAX 2) сумма от продаж зеленого продукта по всем фирмам без их индивидуализ-ии
]
end
;;========================================================================= Add1Firm
to Add1Firm
  if (P0 - c1) < 0 or abs (P0 - c1) < 0.005 [output-show "NEGATIVE OR TOO SMALL P0 - C1 VALUE. STOP RUNNING" stop]  ;; 28/08/25
  create-ordered-firms 1
  [
    set size 2 set shape "person" ;;"building store"

    setxy random-xcor random-ycor
    set color blue

    FirmsSettings


    set QM 0
    set Profit 0
    set ProfitCumulative 0
    set inmarket true
    set label-color black

    set label Qt ;;who
  ]
set QS sum [Qt] of firms with [inmarket]
set QSBlack sum [Qt] of firms with [inmarket and ([cathegory] of product MyProductID) = "Black"]
end
;;============================================================================    FIRM SETTINGS
to FirmsSettings                    ;; call from firm context !!!!!
  ;;set ACost CostPerMonth
  set ACost  max list (precision (random-normal CostPerMonth  CPMVariation) 1) 0

  if (P0 - c1) < 0 or abs (P0 - c1) < 0.005 [output-show "NEGATIVE OR TOO SMALL P0 - C1 VALUE. STOP RUNNING" stop]  ;; 28/08/25
  set QBE precision (ACost / (P0 - c1)) 1


  set Qmax precision (Qmax/QBE * QBE) 0     ;; Qmax/QBE is slider name!!!!
  set Qt precision (Qt/Qmax * Qmax) 0       ;; Qt/Qmax is slider name!!!!
  set GreenTransition false                 ;; 20/08/25

  set Resource Qmax * (random (Duration + 1))    ;;; !!!!!!!!!!!?????? 26 26 26        ;; 26 или (15 + random 11)    ;; NEW 29/06/25 30/06

  (ifelse
    Strategy = "Agressive" [set Strat "A"]
    Strategy = "Neutral" [set Strat "N"]
    Strategy = "Conservative" [set Strat "C"]
    ;; elsecommands
    [ show "Error Strategy value" ])
  let Local1 who
  let Local2 -1    ;;; for Who of Firm's product
  hatch-products 1 [set owner Local1 set stock 0 set price p0        ;;set price p0 !!!!!! NEW 01/07/25
                    set cathegory "Black" set color gray set size 1  ;;set price p0 !!!!!! NEW 01/07/25
                    set xcor xcor + 1 set ycor ycor + 1              ;;set price p0 !!!!!! NEW 01/07/25
                    set Local2 who  ;; Who of product
                   ]
  set MyProductID Local2           ;; show MyProductID
end


;;======================================      ECOLOGY     ==================

to Ecology
  if QS > 0 [set QSTotal QSTotal + QS set Emission Emission + QS]

  set Emission Emission * .995  ;; если производства нет загрязнение медленно уменьшается, варианты .99 .999
  ;; show Emission
end
;;============================================================================ Emission from Black products ONLY !!!!!
to Ecology2
  if QSBlack > 0 [set QSBlackTotal QSBlackTotal + QSBlack set Emission Emission + QSBlack]

  set Emission Emission * .995  ;; если производства нет загрязнение медленно уменьшается, варианты .99 .999

end
;;============================================================================
to Cleaning
  if Emission > 0 [set Emission Emission * .9
                   set TotalCostofCleaning TotalCostofCleaning + CostofCleaning]
  ;;  загрязнение уменьшается в результате очистки
end
;;============================================================================
to EcologyTAX
ask firms with [inmarket]
[ set ETAX QM * CostofCleaning * EcoTAXRate / QS ;;;(.1 * Emission) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    if QM > 0 [set ProfitCumulative ProfitCumulative - ETAX set ETAXTotal ETAXTotal + ETAX  write "ETAX" show precision ETAX 0] ;;show who
]
end
;;============================================================================
to EcologyTAX2
ask firms with [inmarket and ([cathegory] of product MyProductID) = "Black"]
[ set ETAX Qt * CostofCleaning * EcoTAXRate / QSBlack
    if Qt > 0 [set ProfitCumulative ProfitCumulative - ETAX set ETAXTotal ETAXTotal + ETAX  write "ETAX" show precision ETAX 0] ;;show who
]
end
;; ================================================ GREEN DECISION    ===========================
to GreenDecision

ask firms with [inmarket and not GreenTransition]
  [ Let L 0
    if Clean   [set L L + 30]
    if EcoTAX  [set L L + 10]
    if EcoTAXRate > 1 [set L L + 10]
    if SubsidyON [set L L + 20]
    if SubsidyRate > 0.25 [set L L + 10]         ;; 90 MAX
    if SubsidyRate > 0.5  [set L L + 10]         ;; 100

    if random 100 < L  [set GreenTransition true]

  ]
end
;;=================================================    EQUIPMENT      ===========================
to EquipmentDecision
ask firms with [inmarket]
[
  if Resource < Qt
    [ifelse ProfitCumulative > 0
     [
      let Corrector .5
      (ifelse
      Strat = "A" [set Corrector .6]    ;; .75
      Strat = "N" [set Corrector .4]     ;; .5
      Strat = "C" [set Corrector .2]    ;; .25
      ;; elsecommands
      [ show "Error Corrector EquipmentDecision"])

        ;;;                 EngineCost slider, Cost of 1000 units per Month Engine

            let EnPower precision (Corrector * ProfitCumulative / EngineCost) 0 write "EnPower" show EnPower
            let LWho who           ;; NEW 22/07/25

    ;; Corrector * ProfitCumulative is Upgrade Fund
    ;; ProfitCumulative / EngineCost is quantity of Engines with productivity 1000 units per Month. How much the Engines Firm can buy?
    ;; Cost of 1000 units per month Engine = EngineCost   Constants: 25 * 100 (Thousands) = 2,5 mln

             ifelse EnPower > 0
                    [set Qmax EnPower * 1000                                        ;;; NEW ENGINE

                     set Resource QMax * Duration  ;;; !!!!!!!!!!!?????? 25 25 25         ;;; NEW ENGINE

                     set ProfitCumulative ProfitCumulative - EnPower * EngineCost   ;;; NEW ENGINE for Strat setted part of Firm's Profit
                     set Qt min list Qt Qmax                                        ;;; NEW ENGINE
                     set SumForSubsidy EnPower * EngineCost
                    ask products with [owner = Lwho] [die]                           ;; NEW 22/07/25
                    let Local1 Who ;; Of Firm
                    hatch-products 1
                    [
                      set owner LWho set stock 0 set price p0        ;; NEW 22/07/25

                    ;; ifelse (random 100) < GreenProbability                     ;; slider OLD VERSION

                    ifelse [GreenTransition] of firm Lwho                   ;; 20/08/25 INSTEAD ifelse (random 100) < GreenProbability

                         [set cathegory "Green" set color green set size 2 ]                ;; NEW 10/08/25
                         [set cathegory "Black" set color gray  set size 2 ]               ;; NEW 10/08/25
                      set xcor xcor + 1 set ycor ycor + 1 set label ""                 ;; NEW 22/07/25
                      set Local1 who  ;; of product
                    ]
            ;; убили старый продукт и создали новый с категорией green/black
            ;; теперь Qt будет относисться уже к новому продукту
                    set MyProductID Local1 ;; show MyProductID
                    ]                                                         ;;; NEW ENGINE
        [show "Havn't enough funds for new Engine" set Qt 0 set Resource 0 if MarketOff [set inmarket false]] ;; 23/07/2025
       ]
       [show "Losses" set Qt 0 set Resource 0 if MarketOff [set inmarket false]] ;; else ProfitCumulative > 0 ;; 23/07/2025
    ]


]
end
;;==============================================================================
to Subsidy?
  if SubsidyON
  [
    ask firms with [inmarket]
    [
      let Lwho who
      let LCathegory [cathegory] of products with [owner = Lwho]
      if  LCathegory = ["Green"]      ;; the Firm produce Green product.  ;;; = ["Green"] !!!!!! OOOOnly this way!!!!
      [
        set ProfitCumulative ProfitCumulative + SumForSubsidy * SubsidyRate
        set SubsidyTotal SubsidyTotal + SumForSubsidy * SubsidyRate        ;; Add The Subsidy to budget support amount
        set SumForSubsidy 0
      ]
    ]
  ]
end
;;==================================================     NEW PROCEURES   ============================
to SetPrices
  ask products [set price PRECISION (random-normal price (price / 100)) 3  show price]
end
;;==============================================================================
to MultiPricesMarket
  let LMoney W let LQD 0 let Market 0             ;; shopping ON


  ask  products with [stock > 0 and price > 0]
  [ set Market Market + price * stock ] show Market   ;; All Supply now in Money
  Let LTotalStock sum [stock] of products with [stock > 0 and price > 0] ;; All Supply now in Units
  Set PriceMean Market / LTotalStock
  Set QD precision (W / PriceMean) 0

    if LMoney >= Market
    [
      ask products with [stock > 0 and price > 0]
      [
      set LMoney LMoney - stock * price
      set LQD LQD + stock

      let Lwho owner
      let LStock stock
      ask Firms with [who = Lwho] [set QM Lstock] ;;;    set [QM] of Firm to sold quantity

      set stock 0

      write LMoney show LQD
      ]
    ]

 ;; let L [who] of products with min price

  ;;set QD LQD




  ;; show sort-on [stock] products
  ;;show min-n-of 5 products [price]

end
;;===========================================================   IN PROGRESS !!! NOT 4 GO    ===================
to ControlParamCorrection                                        ;; NEW 08/08/25
 ask firms with [inmarket]
[
    set QBE precision (ACost / (P0 - c1)) 1     ;; QBE update    ;; NEW 08/08/25
    ;; выявлена ошибка при P0 = c1 деление на 0
    ;; пока процедуру не выполняем на шаге go
]
end
;;===========================================================    VISUALISATION  ===================
to SHOWLabels
  ask firms [
      (ifelse
      FirmValue = "Resource" [set label Resource]
      FirmValue = "Qt" [set label Qt]
      FirmValue = "Strat" [set label Strat]
      FirmValue = "Qbe" [set label precision Qbe 0]
      FirmValue = "CostPerMonth" [set label ACost]
      FirmValue = "ProfitСumulative" [set label precision ProfitCumulative 0]
      FirmValue = "Last Month Profit" [set label precision Profit 0]
      FirmValue = "QMax" [set label QMax]
      FirmValue = "QM" [set label QM]
      ;; elsecommands
      [ show "SHOWLabels Error"])
  ]
    ask products [
      (ifelse
      ProductValue = "Stock" [set label precision Stock 0]
      ProductValue = "Price" [set label Price]
      ;; elsecommands
      [ show "SHOWLabels Error"])
  ]
end
;;=================================================================   TO DELETE ????? =============
to UpgradeEstimation
ask firms with [inmarket]
[ show Qmax show Qmax * 25 show ProfitCumulative
  ifelse ProfitCumulative > 0 [show precision (ProfitCumulative / 2500) 0]
    ;; ProfitCumulative / 2500 is quantity of Engines with productivity 1000 units per Month. How much the Engines Firm can buy?
                              [show 0]

  ;; Cost of 1000 units per month Engine = 25 * 100 (Thousands) = 2,5 mln
  ;; [set ProfitCumulative ProfitCumulative - CostofEngine    show who show precision ETAX 0]
]
end
@#$#@#$#@
GRAPHICS-WINDOW
298
10
832
545
-1
-1
15.94
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

SLIDER
30
184
138
217
FirmsQty
FirmsQty
1
30
20.0
1
1
NIL
HORIZONTAL

BUTTON
3
10
81
65
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
83
10
163
65
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
844
11
1016
44
dP%
dP%
0
20
2.0
1
1
NIL
HORIZONTAL

SLIDER
845
50
1017
83
dQ%
dQ%
0
20
5.0
1
1
NIL
HORIZONTAL

SLIDER
844
87
1016
120
C1
C1
.5
.99
0.75
.025
1
NIL
HORIZONTAL

SLIDER
870
124
983
157
P0
P0
1
5
0.659
1
1
NIL
HORIZONTAL

SLIDER
1022
10
1194
43
TAX%
TAX%
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
1022
49
1194
82
W
W
10000
100000
100000.0
5000
1
NIL
HORIZONTAL

PLOT
840
186
1040
366
QS QD
NIL
NIL
0.0
10.0
0.0
200.0
true
false
"" ""
PENS
"default" 1.0 0 -14439633 true "" "plot qs"
"pen-1" 1.0 0 -2674135 true "" "plot qd"

MONITOR
989
125
1074
170
QS (of firms)
precision QS 0
17
1
11

MONITOR
1073
125
1141
170
NIL
QD
17
1
11

BUTTON
4
70
163
112
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
841
371
1041
550
Price
NIL
NIL
0.0
10.0
0.0
3.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot p0"
"pen-1" 1.0 0 -7500403 true "" "plot 2"
"pen-2" 1.0 0 -2674135 true "" "plot 1"

PLOT
470
558
668
686
TotalCumulativeProfit - Investments
NIL
NIL
0.0
10.0
0.0
10000.0
true
false
"" ""
PENS
"default" 1.0 0 -5298144 true "" "plot sum [ProfitCumulative] of firms with [not inmarket]"
"pen-1" 1.0 0 -7500403 true "" "plot sum [ProfitCumulative] of firms with [inmarket]"
"pen-2" 1.0 0 -14070903 true "" "plot 0"

BUTTON
200
56
259
95
Add1Firm
Add1Firm
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
30
219
151
264
Current Firms Q-ty
count firms with [inmarket]
1
1
11

PLOT
1045
186
1243
366
TaxTotal/CostOfClean/EcolTax
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -11085214 true "" "plot TaxTotal"
"pen-1" 1.0 2 -2674135 true "" "plot TotalCostofCleaning"
"pen-2" 1.0 0 -13210332 true "" "plot ETAXTotal"
"pen-3" 1.0 0 -13345367 true "" "plot SubsidyTotal"
"pen-4" 1.0 0 -16777216 true "" "plot BudgetBalance"

CHOOSER
201
10
294
55
MarketOff
MarketOff
true false
0

PLOT
881
558
1079
684
Emission
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot Emission"
"pen-1" 1.0 0 -7500403 true "" "plot EmissionCritical"

SLIDER
29
268
142
301
CostPerMonth
CostPerMonth
500
5000
500.0
100
1
NIL
HORIZONTAL

SLIDER
179
149
296
182
CostofCleaning
CostofCleaning
1000
25000
8000.0
1000
1
NIL
HORIZONTAL

SLIDER
29
303
142
336
CPMVariation
CPMVariation
0
1000
100.0
100
1
NIL
HORIZONTAL

PLOT
677
558
873
684
mean [Resource]
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [Resource] of Firms"

CHOOSER
29
338
141
383
Strategy
Strategy
"Agressive" "Neutral" "Conservative"
0

PLOT
1088
556
1285
682
Product Stock
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [stock] of products"

SLIDER
1022
87
1194
120
EmissionCritical
EmissionCritical
0
5000000
2000000.0
1000000
1
NIL
HORIZONTAL

CHOOSER
179
184
297
229
EcoTAX
EcoTAX
true false
0

CHOOSER
181
384
281
429
FirmValue
FirmValue
"Resource" "Qt" "Qbe" "QMax" "QM" "Strat" "CostPerMonth" "ProfitСumulative" "Last Month Profit"
5

CHOOSER
181
432
282
477
ProductValue
ProductValue
"Stock" "Price"
1

CHOOSER
179
268
297
313
SubsidyON
SubsidyON
true false
1

SLIDER
179
316
297
349
SubsidyRate
SubsidyRate
0
1
0.25
.25
1
NIL
HORIZONTAL

CHOOSER
179
103
296
148
Clean
Clean
true false
0

PLOT
1206
24
1425
146
QSBlack
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot QSBlacktotal"
"pen-1" 1.0 0 -7500403 true "" "plot QStotal"

MONITOR
1291
93
1382
138
Black Production
precision QSBlack 0
17
1
11

SLIDER
30
386
140
419
Qt/Qmax
Qt/Qmax
0.1
1
0.5
.1
1
NIL
HORIZONTAL

SLIDER
30
420
140
453
Qmax/QBE
Qmax/QBE
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
29
456
141
489
EngineCost
EngineCost
1000
10000
2500.0
500
1
NIL
HORIZONTAL

PLOT
263
559
461
685
Inmarket Grn / Blck Profit
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -14439633 true "" "plot GreenProfit"
"pen-1" 1.0 0 -16777216 true "" "plot BlackProfit"

PLOT
56
558
252
685
Green / Black Sales
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot BlackSales"
"pen-1" 1.0 0 -14439633 true "" "plot GreenSales"

SLIDER
172
491
291
524
GreenProbability
GreenProbability
0
99
78.0
1
1
NIL
HORIZONTAL

SLIDER
180
231
298
264
EcoTAXRate
EcoTAXRate
0.5
3
1.0
.5
1
NIL
HORIZONTAL

SLIDER
172
521
291
554
Duration
Duration
1
26
26.0
1
1
NIL
HORIZONTAL

OUTPUT
1048
372
1284
549
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

building store
false
0
Rectangle -7500403 true true 30 45 45 240
Rectangle -16777216 false false 30 45 45 165
Rectangle -7500403 true true 15 165 285 255
Rectangle -16777216 true false 120 195 180 255
Line -7500403 true 150 195 150 255
Rectangle -16777216 true false 30 180 105 240
Rectangle -16777216 true false 195 180 270 240
Line -16777216 false 0 165 300 165
Polygon -7500403 true true 0 165 45 135 60 90 240 90 255 135 300 165
Rectangle -7500403 true true 0 0 75 45
Rectangle -16777216 false false 0 0 75 45

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="CostPerMonth">
      <value value="1300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="P0">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="FirmValue">
      <value value="&quot;ProfitСumulative&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dQ%">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MarketOff">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CPMVariation">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ProductValue">
      <value value="&quot;Stock&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="FirmsQty">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CleaningAndEcTAX">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TAX%">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EmissionCritical">
      <value value="5000000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CostofCleaning">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C1">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Strategy">
      <value value="&quot;Agressive&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="W">
      <value value="100000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dP%">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
