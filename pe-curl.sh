#!/usr/bin/env zsh

zparseopts -A ARGUMENTS -id: -pass: -zip:

identifiant=$ARGUMENTS[--id]
password=$ARGUMENTS[--pass]
zipcode=$ARGUMENTS[--zip]

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

# Grab preliminary infos
echo "Démarrage d'une session pole-emploi..."
auth_page=`curl -s -k --cookie-jar cookies.txt https://candidat.pole-emploi.fr/candidat/espacepersonnel/authentification`
formdata=`echo $auth_page | grep -oE value="\"(.*)\" name=\"t:formdata\"" | cut -d'"' -f2`
formaction=`echo $auth_page | grep -oE "action=\"(.*)\" method=\"post\" id=\"formulaire\">" | cut -d'"' -f2`

# First you have to provide your login id
echo "Pré-authentification..."
auth_page2=`curl -s -k -L "https://candidat.pole-emploi.fr$formaction" --data-urlencode "t%3Aformdata=$formdata" --data "champTexteIdentifiant=$identifiant&t%3Asubmit=%5B%22boutonContinuer%22%2C%22boutonContinuer%22%5D&boutonContinuer=Poursuivre" --cookie cookies.txt --cookie-jar cookies.txt`
formdata=`echo $auth_page2 | grep -oE value="\"(.*)\" name=\"t:formdata\"" | cut -d'"' -f2`
formaction=`echo $auth_page2 | grep -oE "action=\"(.*)\" method=\"post\" id=\"formulaire\">" | cut -d'"' -f2`

# Now login for good
echo "Authentification..."
home_candidat=`curl -s -k -L "https://candidat.pole-emploi.fr$formaction" --data-urlencode "t%3Aformdata=$formdata" --data "t%3Asubmit=%5B%22boutonValider%22%2C%22boutonValider%22%5D&champMotDePasse=$password&champTexteCodePostal=$zipcode&boutonValider=Se+connecter" --cookie cookies.txt --cookie-jar cookies.txt`

echo "Récupération des courriers..."

# we first get a page that is a javascript submited form, so we need to submit the form on our own, this adds a new cookie with the courrier session ID
mes_courriers=`curl -s -k -L "https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements/mesechangesavecpoleemploi.mes_courriers:debrancherversleservice" --cookie cookies.txt`
action=`echo $mes_courriers | grep -oe "action=\".*\"/>" | cut -d'"' -f2`
jeton=`echo $mes_courriers | grep -oe "value=\".*\"/>" | cut -d'"' -f2`

# Ok, done, now grab the actual mail list page.
courriers=`curl -s -k -L "$action" --data-urlencode "jeton=$jeton" --cookie cookies.txt --cookie-jar cookies.txt`

# extract mail links (first filtering table.listingPyjama only thanks to hxselect)
liens_courriers=`echo $courriers | hxselect table.listingPyjama | hxwls -b "$action"`

# If we found no links at all, we just state that and return
if [ -z $liens_courriers ]; then
  print -P "%BAucun courrier n'a été trouvé%b"
  return
fi

# Loop over our links
printf '%s\n' "$liens_courriers" | while IFS= read -r lien
do
  #echo "${GREEN}[Courrier trouvé]${RESET} $lien"

  # grab only the mail number, which is going to be the pdf filename
  num_pdf=`echo $lien | grep -oE "\d+$"`

  # Check if the pdf is already present in the current directory
  if [ -f "$num_pdf.pdf" ]
  then
    # The pdf was found, no need to re-download...
    #echo "Le courrier n°$num_pdf a déjà été téléchargé."
  else

    # If no pdf was found in the current directory, let's download it
    echo "${BOLD_GREEN}[Nouveau courrier]${RESET} Courrier n°$num_pdf..."
    # this should NOT BE NEEDED since it's just a wrapper for displaying the pdf file in an iframe when you are using a browser
    # HOWEVER commenting the request will trigger a 500 error on the server... so yeah, we'll just keep that extra request
    page_courrier=`curl -s -k -L "$lien" --cookie cookies.txt`
    #lien_pdf=`echo $page_courrier |  hxselect iframe | sed "s/.* src=\"\(.*\)\".*/\1/"`
    #echo $lien_pdf
    #fichier_pdf=`curl -k -L -O "https://courriers.pole-emploi.fr$lien_pdf" --cookie cookies.txt`

    # Grab the pdf and save it to the current directory
    fichier_pdf=`curl -k -L --progress-bar -o "$num_pdf.pdf" "https://courriers.pole-emploi.fr/courriersweb/affichagepdf:pdf/$num_pdf" --cookie cookies.txt`
  fi

done

# Delete cookies ?! http://img12.deviantart.net/d497/i/2015/287/8/5/cookie_monster_____by_supergecko99-d9d2smd.png
rm cookies.txt
