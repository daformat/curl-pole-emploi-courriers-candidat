#!/usr/bin/env zsh

# Tests to check nothing has changed on pole-emploi

# just in case
export PATH=/usr/local/bin:$PATH


# Parse arguments
zparseopts -A ARGUMENTS -id: -pass: -zip:

identifiant=$ARGUMENTS[--id]
password=$ARGUMENTS[--pass]
zipcode=$ARGUMENTS[--zip]


# Setup text colors
autoload colors
if [[ "$terminfo[colors]" -gt 8 ]]; then
    colors
fi
for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
    eval $COLOR='$fg_no_bold[${(L)COLOR}]'
    eval BOLD_$COLOR='$fg_bold[${(L)COLOR}]'
done
eval RESET='$reset_color'


# Ask for login info if they were not provided as arguments
while [ -z $identifiant ]; do
  print -P -n "%BIdentifiant Pôle-Emploi :%b "
  read identifiant
done
while [ -z $password ]; do
  print -P -n "%BMot de passe :%b "
  read password
done
while [ -z $zipcode ]; do
  print -P -n "%BCode postal :%b "
  read zipcode
done

erreurs=0

fail() {
  print -P "${BOLD_RED}[Erreur]${RESET} $1"
  let 'erreurs++'
}
succeed() {
  print -P "${BOLD_GREEN}[Ok]${RESET} $1"
}


# ---

echo '\nVérifications préliminaires'

auth_page_url='https://candidat.pole-emploi.fr/candidat/espacepersonnel/authentification'
auth_page=`curl -s -k -D - $auth_page_url --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
auth_page_http_status=`echo $auth_page | grep -o 'HTTP/1.1 200 OK'`
if [ -z $auth_page_http_status ]
then
  fail "La page $auth_page_url a un code HTTP inattendu"
else
  succeed "Code HTTP 200 pour la page $auth_page_url"
fi


# Tester qu'on peut bien récupérer le formulaire habituel (#formulaire)
form=`echo $auth_page | hxselect '#formulaire'`
if [ -z $form ]
then
  fail "Impossible de trouver un formulaire sur la page $auth_page_url"
else
  succeed "L'élément #formulaire a bien été trouvé"
fi

# Vérifions maintenant qu'on arriver à récupérer l'action du form ainsi que le paramètre t:formdata qui devra être transmis lors des prochaines étapes
formaction=`echo $auth_page | grep -oE "action=\"(.*)\" method=\"post\" id=\"formulaire\">" | cut -d'"' -f2`
formdata=`echo $auth_page | grep -oE value="\"(.*)\" name=\"t:formdata\"" | cut -d'"' -f2`

if [ -z $formaction ]
then
  fail "L'action du formulaire est introuvable !"
else
  succeed "Action récupérée pour le formulaire ($formaction)"
fi

test=`echo $formaction | grep -E '^/candidat/espacepersonnel/authentification/index\.formulaire;JSESSIONID_CANDIDAT=.*$'`
if [ -z $test ]
then
  fail "L'action du formulaire semble différente de ce qui est attendu"
else
  succeed "L'action semble conforme aux attentes"
fi

if [ -z $formdata ]
then
  fail "Impossible de trouver le paramètre t:formdata dans le formulaire !"
else
  succeed "Paramètre t:formdata correctement extrait"
fi



echo "\nPré-authentification..."
print -P "%BIdentifiant :%b $identifiant"
auth_page2_url="https://candidat.pole-emploi.fr$formaction"
auth_page2=`curl -s -k -L -D - $auth_page2_url --data-urlencode "t%3Aformdata=$formdata" --data "champTexteIdentifiant=$identifiant&t%3Asubmit=%5B%22boutonContinuer%22%2C%22boutonContinuer%22%5D&boutonContinuer=Poursuivre" --cookie cookies.txt --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
auth_page2_http_status=`echo $auth_page2 | grep -o 'HTTP/1.1 200 OK'`
if [ -z $auth_page2_http_status ]
then
  fail "La page $auth_page2_url a un code HTTP inattendu"
else
  succeed "Code HTTP 200 pour la page $auth_page2_url"
fi

formdata=`echo $auth_page2 | grep -oE value="\"(.*)\" name=\"t:formdata\"" | cut -d'"' -f2`
formaction=`echo $auth_page2 | grep -oE "action=\"(.*)\" method=\"post\" id=\"formulaire\">" | cut -d'"' -f2`

if [ -z $formaction ]
then
  fail "L'action du formulaire est introuvable !"
else
  succeed "Action récupérée pour le formulaire ($formaction)"
fi

test=`echo $formaction | grep -E '^/candidat/espacepersonnel/authentification/index\.formulaire$'`
if [ -z $test ]
then
  fail "L'action du formulaire est différente de ce qui est attendu"
else
  succeed "L'action est conforme aux attentes"
fi

if [ -z $formdata ]
then
  fail "Impossible de trouver le paramètre t:formdata dans le formulaire !"
else
  succeed "Paramètre t:formdata correctement extrait"
fi



echo "\nAuthentification..."
print -P "%BMot de passe :%b $password"
print -P "%BCode postal :%b $zipcode"
home_candidat=`curl -s -k -L -D - "https://candidat.pole-emploi.fr$formaction" --data-urlencode "t%3Aformdata=$formdata" --data "t%3Asubmit=%5B%22boutonValider%22%2C%22boutonValider%22%5D&champMotDePasse=$password&champTexteCodePostal=$zipcode&boutonValider=Se+connecter" --cookie cookies.txt --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
home_candidat_http_status=`echo $home_candidat | grep -o 'HTTP/1.1 200 OK'`
if [ -z $home_candidat_http_status ]
then
  fail "L'authentification a renvoyé a un code HTTP inattendu"
else
  succeed "Authentification réussie"
fi

# Vérifions que nous avons bien été renvoyés à l'adresse habituelle
test_location=`echo $home_candidat | grep -o 'Location: https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements'`

if [ -z $test_location ]
then
  fail "L'authentification n'a pas renvoyé vers l'adresse habituelle"
  test_location2=`echo $home_candidat | grep -o 'Location: https://candidat.pole-emploi.fr/candidat/espacepersonnel/authentification'`
  if [ ! -z $test_location2 ]; then
    fail "Les informations de connexions semblent fausses (redirigé à nouveau vers l'authentification)"
  fi
else
  succeed "Correctement renvoyé vers l'espace personnel (https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements)"
fi


echo "\nVérification de la disponibilité du service courrier..."
# we first get a page that is a javascript submited form, so we need to submit the form on our own, this adds a new cookie with the courrier session ID
url="https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements/mesechangesavecpoleemploi.mes_courriers:debrancherversleservice"
mes_courriers=`curl -s -k -D - -L "$url" --cookie cookies.txt`
action=`echo $mes_courriers | grep -oe "action=\".*\"/>" | cut -d'"' -f2`
jeton=`echo $mes_courriers | grep -oe "value=\".*\"/>" | cut -d'"' -f2`

# Vérifions qu'on obtient bien un code 200
mes_courriers_http_status=`echo $mes_courriers | grep -o 'HTTP/1.1 200 OK'`
if [ -z $mes_courriers_http_status ]
then
  fail "Le service courrier a renvoyé a un code HTTP inattendu"
else
  succeed "Service courrier contacté avec succès à l'adresse habituelle"
fi

# Vérifions que nous avons bien une action
if [ -z $action ]
then
  fail "Impossible de trouver une action le formulaire de courrier"
else
  succeed "Action trouvée ($action)"
fi


# Vérifions que nous avons bien un jeton
if [ -z $jeton ]
then
  fail "Impossible de trouver un jeton pour le formulaire de courrier"
else
  succeed "Jeton pour le courrier PE trouvé ($jeton)"
fi


echo "\nRécupération de la page courrier"

# Ok, done, now grab the actual mail list page.
courriers=`curl -s -k -D - -L "$action" --data-urlencode "jeton=$jeton" --cookie cookies.txt --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
courriers_http_status=`echo $mes_courriers | grep -o 'HTTP/1.1 200 OK'`
if [ -z $courriers_http_status ]
then
  fail "Code HTTP inattendu"
else
  succeed "Liste des derniers courriers reçue"
fi


liens_courriers=`echo $courriers | hxselect table.listingPyjama | hxwls -b "$action"`

# Vérifions les liens trouvés
if [ -z $liens_courriers ]
then
  fail "Aucun courrier n'a été trouvé dans la liste"
else
  succeed "Le liste de courriers reçue n'est pas vide"
  echo "\nCourriers disponbiles : "
  echo $liens_courriers
fi

# Récap final
if [[ $erreurs -gt O ]]
then
  print -P "\n${BOLD_RED}Nombre d'erreurs détéctées : $erreurs${RESET}"
else
  print -P "\n${BOLD_GREEN}Aucun problème détécté${RESET}"
fi

rm cookies.txt