#!/usr/bin/env zsh

# Tests to check nothing has changed on pole-emploi

# just in case
export PATH=/usr/local/bin:$PATH

# ---

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

# ---

# Output helpers
erreurs=0
succes=0
test_sets=0
fail() {
  print -P "${BOLD_RED}[Erreur]${RESET} $1"
  let 'erreurs++'
}
warn() {
  print -P "${BOLD_YELLOW}[Warning]${RESET} $1"
}
succeed() {
  print -P "${BOLD_GREEN}[Ok]${RESET} $1"
  let 'succes++'
}
info() {
  print -P "${BOLD_CYAN}[Info]${RESET} $1"
}
new_test_set() {
  let 'test_sets++'
  print -P "\n${BOLD_BLUE}[Étape $test_sets]${RESET} $1"
}
print_time() {
  printf '%dh:%dm:%ds' $(($1/3600)) $(($1%3600/60)) $(($1%60))
}


# ---

# Configuration / options

# Parse arguments
zparseopts -A ARGUMENTS -id: -pass: -zip: -imsg: -conf:

config_file=$ARGUMENTS[--conf]

script_dir=`dirname $0`
#echo "Configuration demandée : "$config_file
if [ -z $config_file ]; then
  config_file="$script_dir/pe.conf"
fi
#echo "Configuration utilisée : "$config_file

# Default configuration
typeset -A config

config=(
  pdf_directory '.'
  shut_up false
)

# Parse configuration file if readable
if [ -r $config_file ]
then
  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      varname=$(echo "$line" | cut -d '=' -f 1)
      config[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $config_file
fi

# Override configuration file values with script options when given any
if [ ! -z $ARGUMENTS[--id] ]; then
  config[identifiant]=$ARGUMENTS[--id]
fi

if [ ! -z $ARGUMENTS[--pass] ]; then
  config[password]=$ARGUMENTS[--pass]
fi

if [ ! -z $ARGUMENTS[--zip] ]; then
  config[zipcode]=$ARGUMENTS[--zip]
fi

if [ ! -z $ARGUMENTS[--pdf-dir] ]; then
  config[pdf_directory]=$ARGUMENTS[--pdf-dir]
fi

if [ ! -z $ARGUMENTS[--imsg] ]; then
  config[imessage_address]=$ARGUMENTS[--imsg]
fi

if [[ $* == *--shut-the-fuck-up* ]]; then
  config[shut_up]=true
fi

# echo $config[@]

# Expand relative paths
config[pdf_directory]=$(eval cd $config[pdf_directory]; pwd)

# echo $config[@]

# Using variables as a shorthand
identifiant=$config[identifiant]
password=$config[password] # this should be provided via a config file so it's more secure
zipcode=$config[zipcode]
pdf_directory=${config[pdf_directory]%/} # the ${var%/} notation is used to remove the eventual trailing slash
imessage_address=$config[imessage_address]


# ---

# Prompt for any missing required info

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

# ---

# Start tests

# ---

start_time=`date +%s`
print -P "\n%B[0h:0m:0s]%b - Démarrage des tests"

new_test_set "Vérifications préliminaires, démarrage de la session..."

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


# ---

new_test_set "Pré-authentification..."

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


# ---

new_test_set "Authentification..."

print -P "%BMot de passe :%b " $(echo $password | sed -e 's/./•/g')
print -P "%BCode postal :%b $zipcode"
home_candidat=`curl -s -k -L -D - "https://candidat.pole-emploi.fr$formaction" --data-urlencode "t%3Aformdata=$formdata" --data "t%3Asubmit=%5B%22boutonValider%22%2C%22boutonValider%22%5D&champMotDePasse=$password&champTexteCodePostal=$zipcode&boutonValider=Se+connecter" --cookie cookies.txt --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
home_candidat_http_status=`echo $home_candidat | grep -o 'HTTP/1.1 200 OK'`
if [ -z $home_candidat_http_status ]
then
  fail "La requête d'authentification a renvoyé a un code HTTP inattendu"
else
  succeed "La requête d'authentification a réussi (code HTTP 200)"
fi

# Vérifions que nous avons bien été renvoyés à l'adresse habituelle
test_location=`echo $home_candidat | grep -o 'Location: https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements'`

if [ -z $test_location ]
then
  fail "L'authentification n'a pas renvoyé vers l'adresse habituelle"
  test_location2=`echo $home_candidat | grep -o 'Location: https://candidat.pole-emploi.fr/candidat/espacepersonnel/authentification'`
  if [ ! -z $test_location2 ]; then
    warn "Les informations de connexions semblent fausses (redirigé à nouveau vers l'authentification)"
  fi
else
  succeed "Correctement renvoyé vers l'espace personnel (https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements)"
fi


# ---

new_test_set "Vérification de la capacité à accéder au service courrier..."

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
  fail "Impossible de trouver un jeton dans le formulaire d'identification du service courrier"
else
  succeed "Jeton d'accès pour le service courrier obtenu ($jeton)"
fi


# ---

new_test_set "Récupération de la liste de courriers récents..."

# Ok, done, now grab the actual mail list page.
courriers=`curl -s -k -D - -L "$action" --data-urlencode "jeton=$jeton" --cookie cookies.txt --cookie-jar cookies.txt`

# Vérifions qu'on obtient bien un code 200
courriers_http_status=`echo $mes_courriers | grep -o 'HTTP/1.1 200 OK'`
if [ -z $courriers_http_status ]
then
  fail "Code HTTP inattendu"
else
  succeed "Liste des derniers courriers obtenue avec succès"
fi

# On récupère tous les liens
liens_courriers=`echo $courriers | hxselect table.listingPyjama | hxwls -b "$action"`

# Vérifions les liens trouvés
if [ -z $liens_courriers ]
then
  fail "Aucun courrier n'a été trouvé dans la liste"
else
  succeed "Le liste de courriers reçue n'est pas vide"
  # echo $liens_courriers
fi


# ---

new_test_set "Vérification de la possibilité de télécharger les courriers..."

if [ -z $liens_courriers ]; then
  info 'Pas de courrier trouvé, aucun test effectué'
fi

# Bouclons sur les liens trouvés
printf '%s\n' "$liens_courriers" | while IFS= read -r lien
do
  if [ ! -w $lien ]; then
    #print -P "%U$lien%u"
    # grab only the mail number, which is going to be the pdf filename
    num_pdf=`echo $lien | grep -oE "\d+$"`

    # this should NOT BE NEEDED since it's just a wrapper for displaying the pdf file in an iframe when you are using a browser
    # HOWEVER commenting the request will trigger a 500 error on the server... so yeah, we'll just keep that extra request
    page_courrier=`curl -s -k -L "$lien" --cookie cookies.txt`

    # Try to get the PDF
    fichier_pdf=`curl -k -s -I "https://courriers.pole-emploi.fr/courriersweb/affichagepdf:pdf/$num_pdf" --cookie cookies.txt`
    http_status=`echo $fichier_pdf | grep -o 'HTTP/1.1 200 OK'`
    if [ -z $http_status ]
    then
      fail "Code HTTP inattendu lors du téléchargement du courrier n°$num_pdf"
    else
      succeed "Courrier n°$num_pdf téléchargeable"
    fi
  fi

done


# ---

# Récap final

end_time=`date +%s`
run_time=$((end_time-start_time))
t=$(print_time $run_time)

print -P "\n%B[$t]%b - Terminé"

if [[ $erreurs -gt O ]]
then
  print -P "\n${BOLD_GREEN}Nombre de succès détéctés : $succes${RESET}"
  print -P "${BOLD_RED}Nombre d'erreurs détéctées : $erreurs${RESET}"
  if hash osascript 2>/dev/null;
  then
    if [ ! -z $imessage_address ]
    then
      # On balance un iMessage si ça a été demandé...
      osascript<<END
on is_running(appName)
  tell application "System Events" to (name of processes) contains appName
end is_running

set was_running to is_running("Messages")

tell application "Messages"
  set targetService to 1st service whose service type = iMessage
  set targetBuddy to buddy "$imessage_address" of targetService
  send "Des erreurs ont été détéctées lors du script de tests pole-emploi (dans le terminal taper mail pour consulter le résultat de la tache cron)" to targetBuddy
end tell

if was_running is not true then
  quit app "Messages"
end if
END
    fi
  fi
else
  print -P "\n${BOLD_GREEN}Aucun problème détécté${RESET}"
fi

rm cookies.txt
