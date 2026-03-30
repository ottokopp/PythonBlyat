from fsrs import Card

'''
SRS modelliert:
Stability (S) → wie lange du etwas behältst
Difficulty (D) → wie schwer es ist
Retrievability (R) → Erinnerungswahrscheinlichkeit

Kernfunktion:
    R(t)=e^(-t/S), wobei t Zeit seit der letzten wiederholung ist.
    FSRS wählt das nächste Intervall so, dass du etwas wiederholst bevor du es vergisst

    S'=S⋅(1+e^(w3*)D^(-w4*)*S^(-w5)*(e^((1-R)⋅w6)-1))

    eigentlich 17 Parameter die alles steuern, diese werden stätig über den IFRS Optimizer angepasst

    t=-S⋅ln(Rtarget)
    
Nach einer Wiederholung wird S verändert.

Es gibt zwei Fälle:       
                          
1. man erinnert sich nicht(Again):                      2. man erinnert sich(Hard, Good, Easy)

schwere Karten (hohes D) → kleinere S                   gute Antwort → S wächst
Reset-artiges Verhalten                                 je schwerer (D hoch) → weniger Wachstum
                                                        je besser Timing (R niedrig) → mehr Wachstum


'''

from fsrs import Card
from datetime import datetime

class CustomCard(Card):
    def __init__(self, question, answer):
        self.question = question
        self.answer = answer
