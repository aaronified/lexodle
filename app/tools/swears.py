"""Swear words, slurs and vulgar words that no word list should hold.

Hand-picked per language, after going through the hits of the LDNOOBW lists
(github.com/LDNOOBW, CC BY 4.0) against the shipped lists: that list also holds
ordinary words (comer, mama, hård, sexy), which are kept here. Anatomy and
clinical words (penis, vagina, nipple) are not swears and stay. A word matches
as written or with its accents removed.

    python swears.py        remove them from the shipped lists and languages.json
"""
import json
import sys
import unicodedata
from pathlib import Path

WORDS = Path(__file__).resolve().parent.parent / "assets" / "words"

SWEARS = {
    "en": """shit shits shitty fuck fucks fucked fucker fucking dick dicks cock cocks cunt cunts twat clit
        slut sluts slutty whore whores bitch bitches bitchy tits titty titties pussy porn porno milf orgy
        wank wanks wanker coon coons poof kike spic negro nigga nigger faggot fag fags dyke horny dildo
        boner twink spunk tosser nympho asshole bastard pissing blowjob cumming humping spastic
        bullshit bollocks arsehole skeet jizz prick retard rape""",
    "es": """puta putas puto putos culo culos coño verga mierda mierdas pinche cabrón cabron mamada follar
        marica maricón maricon ramera pendejo pendejos pedo joder jodido jodida cojones gilipollas
        capullo zorra polla boludo pelotudo carajo""",
    "fr": """pute putes putain salope salaud enculé encule bordel foutre pisser pédale pédé bander trique
        gouine connard connasse conne conné enfoiré branler branleur tapette chiasse couilles chiottes
        emmerder bite bité bitte nègre négro merde merdé merdeux chier étron nique niquer""",
    "de": """fick ficken ficker fickt fickte fotze fotzen nutte nutten muschi vögeln bumsen pimmel wichse
        wichser wichsen kanake schlampe hure huren arsch neger porno pissen pisser scheiße scheisse""",
    "it": """culo culi figa fica cazzo cazzi merda merde troia troie cagna pirla pippa sorca cagare cagata
        frocio sborra checca belino stronzo stronza stronzi puttana puttane cazzata scopare scopata
        pompino fottere cazzone cornuto zoccola terrone coglioni coglione bordello bocchino trombare
        mignotta sega tette""",
    "pt": """puta putas foda fodas foder merda porra vadia bosta cagar veado viado bicha cacete boceta buceta
        caralho cabrão biscate punheta cona corno queca""",
    "nl": """kont hoer hoerig slet snol drol teef wijf neuken pijpen stront naaien kloten rukken schijt
        schijten beffen hufter oetlul rotzak klootzak flikker shit""",
    "pl": """chuj dupa dupą dupek suka suką srać cipa cipą fiut kurwa kurwy kurwą gówno jebać jebany pojeb
        pojebany pizda pizdą kutas ciota ciotą dziwka dziwką ruchać wkurwiać chujnia burdel""",
    "cs": """srát zmrd píča pica kurva prdel prdelka hovno hajzl čurák kunda mrdat jebat sračka""",
    "da": """lort shit fuck luder fisse røvhul""",
    "hu": """szar szart szarok fasz faszt pöcs geci gecik kurva picsa punci balfasz seggfej segg seggét pina""",
    "nb": """ræva ræven shit pikk jævla jævlig dritt fitte kuker nigger pakkis ståpikk forbanna""",
    "sv": """fitta pitt runka knulla rövhål neger nigger skita jävlar subba arsle""",
    "tr": """siki sikin siktir götü göte götün götten orospu kaltak taşak yarak sıçmak çingene""",
    "ro": """pula pulă pizda pizdă pizde muie curva curve fute futut cacat căcat sugi târfă tarfa târfe boașe
        coaie cur""",
    "id": """anjing bangsat bajingan kontol memek pepek ngentot jancok sialan brengsek tolol goblok pelacur
        lonte jablay perek bencong banci kampret keparat""",
    "ca": """merda puta putes collons cabró cabrons polla cagar cagada mamada follar fotre fotut gilipolles
        maricó marica putada""",
}


def fold(w):
    return "".join(c for c in unicodedata.normalize("NFD", w) if not unicodedata.combining(c))


BAD = {code: {x for w in ws.split() for x in (w, fold(w))} for code, ws in SWEARS.items()}


def is_swear(code, word):
    bad = BAD.get(code, ())
    return word in bad or fold(word) in bad


def main():
    manifest = json.loads((WORDS / "languages.json").read_text(encoding="utf-8"))
    for e in manifest:
        f = WORDS / f"{e['code']}.txt"
        lines = [l for l in f.read_text(encoding="utf-8").split("\n") if l.strip()]
        keep = [l for l in lines if not is_swear(e["code"], l.split("\t")[0])]
        counts = {}
        for l in keep:
            n = str(len(l.split("\t")[0]))
            counts[n] = counts.get(n, 0) + 1
        f.write_text("\n".join(keep) + "\n", encoding="utf-8")
        e["counts"] = {k: counts.get(k, 0) for k in e["counts"]}
        e["lengths"] = [n for n in e["lengths"] if counts.get(str(n), 0) >= 400]
        print(f"{e['code']}: removed {len(lines) - len(keep)}", file=sys.stderr)
    (WORDS / "languages.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
