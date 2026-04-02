

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

from fsrs import Scheduler, Card, Rating, ReviewLog
from datetime import datetime, timezone  

class CustomCard(Card):
    def __init__(self, question, answer):
        super().__init__() 
        self.question = question
        self.answer = answer

class MultipleChoiceCard(CustomCard):
    def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

class CodeCard(CustomCard):
     def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

class SimpleCard(CustomCard):
    def __init__(self, question, answer):
        super().__init__(question, answer) #kommt aus card klasse deshalb keine deklaration

    def __repr__(self):
        return f"SimpleCard(question='{self.question}',answer='{self.answer}' stability={self.stability})" #ist stablity funktion aus fsrs




class Reviewer:
    def __init__(self):
        self.scheduler = Scheduler()
        self.review_history = []
        self.total_reviews = 0 
    
    def review(self, card, user_answer):
        if user_answer != card.answer:
            rating = Rating.Again
        else:
            rating = Rating.Good 
            #TODO: implementieren timer version

        now = datetime.now(timezone.utc)

        reviewed_card, log = self.scheduler.review_card(card, rating, now)

        #history log
        self.review_history.append(log)
        self.total_reviews += 1

        return reviewed_card, log

reviewer = Reviewer()
karte = SimpleCard("Größte Stadt Kasachstans", "Almaty")

# Review durchführen
neue_karte, log = reviewer.review(karte, "Almaty")

print(neue_karte)
print(f"Rating: {log.rating.name}")  

#TODO to_dict() und customtodict()
print(f"Nächster Review der Karte: {neue_karte.due}") #due ist wann man wieder karte lernen soll
#print(f"Nächster Review in: {log.scheduled_days} Days")

'''
class CustomCard(Card):
    def init(self, id, question, answer):
        super().init(id)
        self.question = question
        self.answer = answer


card = CustomCard(1, "What is the capital of France?", "Paris")
card_dict = card.to_dict()

card_dict["stability"]
card_dict["due"]'''