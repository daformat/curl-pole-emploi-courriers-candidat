#!/usr/bin/env zsh

# just in case
export PATH=/usr/local/bin:$PATH


autoload colors
if [[ "$terminfo[colors]" -gt 8 ]]; then
    colors
fi
for COLOR in RED GREEN YELLOW BLUE MAGENTA CYAN BLACK WHITE; do
    eval $COLOR='$fg_no_bold[${(L)COLOR}]'
    eval BOLD_$COLOR='$fg_bold[${(L)COLOR}]'
done
eval RESET='$reset_color'


zparseopts -A ARGUMENTS -id: -pass: -zip: -pdf-dir: -imsg: -conf:

config_file=$ARGUMENTS[--conf]

script_dir=`dirname $0`
#echo "Configuration demandée : "$config_file

if [ -z $config_file ]; then
  config_file="$script_dir/pe.conf"
fi

#echo "Configuration utilisée : "$config_file


# echo "Configuration utilisée : "$config_file

typeset -A config

config=(
  pdf_directory '.'
  shut_up false
)

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

#echo $config[@]

# Expand relative paths
config[pdf_directory]=$(eval cd $config[pdf_directory]; pwd)

#echo $config[@]

identifiant=$config[identifiant]
password=$config[password] # this should be provided via a config file so it's more secure
zipcode=$config[zipcode]
pdf_directory=${config[pdf_directory]%/} # the ${var%/} notation is used to remove the eventual trailing slash
imessage_address=$config[imessage_address]

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

echo "Récupération de la liste des courriers..."

# we first get a page that is a javascript submited form, so we need to submit the form on our own, this adds a new cookie with the courrier session ID
mes_courriers=`curl -s -k -L "https://candidat.pole-emploi.fr/candidat/espacepersonnel/regroupements/mesechangesavecpoleemploi.mes_courriers:debrancherversleservice" --cookie cookies.txt`
action=`echo $mes_courriers | grep -oe "action=\".*\"/>" | cut -d'"' -f2`
jeton=`echo $mes_courriers | grep -oe "value=\".*\"/>" | cut -d'"' -f2`

# Ok, done, now grab the actual mail list page.
courriers=`curl -s -k -L "$action" --data-urlencode "jeton=$jeton" --cookie cookies.txt --cookie-jar cookies.txt`

# extract mail links (first filtering table.listingPyjama only thanks to hxselect)
liens_courriers=`echo $courriers | hxselect table.listingPyjama | hxwls -b "$action"`

# CASE 0: No link was found
# -------------------------
# If we found no links at all, we just state that and return
if [ -z $liens_courriers ]; then
  print -P "%BAucun courrier n'a été trouvé%b"
  return
fi

# -------------------------

# Loop over our links
nouveaux_courriers_telecharges=0
printf '%s\n' "$liens_courriers" | while IFS= read -r lien
do
  #echo "${GREEN}[Courrier trouvé]${RESET} $lien"

  # grab only the mail number, which is going to be the pdf filename
  num_pdf=`echo $lien | grep -oE "\d+$"`

  # Check if the pdf is already present in the current directory
  if [ -f "$pdf_directory/$num_pdf.pdf" ]
  then
    # The pdf was found, no need to re-download...
    #echo "Le courrier n°$num_pdf a déjà été téléchargé."
  else

    # If no pdf was found in the current directory, let's download it
    print -P "%B[Nouveau courrier]%b Téléchargement du courrier n°$num_pdf..."
    # this should NOT BE NEEDED since it's just a wrapper for displaying the pdf file in an iframe when you are using a browser
    # HOWEVER commenting the request will trigger a 500 error on the server... so yeah, we'll just keep that extra request
    page_courrier=`curl -s -k -L "$lien" --cookie cookies.txt`
    #lien_pdf=`echo $page_courrier |  hxselect iframe | sed "s/.* src=\"\(.*\)\".*/\1/"`
    #echo $lien_pdf
    #fichier_pdf=`curl -k -L -O "https://courriers.pole-emploi.fr$lien_pdf" --cookie cookies.txt`

    # Grab the pdf and save it to the current directory
    fichier_pdf=`curl -k -L --progress-bar -o "$pdf_directory/$num_pdf.pdf" "https://courriers.pole-emploi.fr/courriersweb/affichagepdf:pdf/$num_pdf" --cookie cookies.txt`

    # on macOS we can set a color label
    if hash osascript 2>/dev/null;
    then
      # Set the file's label to blue so we can see it's unread
      echo "$pdf_directory/$num_pdf.pdf"
      osascript -e 'property labelColor : {none:0, orange:1, red:2, yellow:3, blue:4, purple:5, green:6, gray:7}' -e "set myPF to POSIX path of \"$pdf_directory/$num_pdf.pdf\"" -e 'tell application "Finder"' -e 'set label index of (POSIX file myPF as alias) to blue of labelColor' -e 'end tell' > /dev/null
    fi

    # finally set the flag so we know at least one pdf was found.
    let 'nouveaux_courriers_telecharges++'
  fi

done

# Ok, now that we're done, let's provide the user some feedback on what was done
if [ $nouveaux_courriers_telecharges -gt 0 ]
then

  # CASE 1: we did find new PDFs to download
  # ----------------------------------------

  # Check how many and pluralize accordingly
  if [ $nouveaux_courriers_telecharges -eq 1 ]
	then
    texte="nouveau courrier téléchargé"
	else
		texte="nouveaux courriers téléchargés"
	fi

  # Store & print output
  output="${BOLD_GREEN}[OK]${RESET} %B$nouveaux_courriers_telecharges $texte%b"
  print -P $output

  # If on macOS, we can have fun using osascript
  if hash osascript 2>/dev/null;
  then
    # Trigger a notification
    osascript -e "display notification \"$nouveaux_courriers_telecharges $texte\" with title \"Pôle emploi\" sound name \"Pop\""
    if [ ! -z $imessage_address ] && [ ! $imessage_address=false ]
    then
      # We can then send an iMessage...
      osascript<<END
  on is_running(appName)
    tell application "System Events" to (name of processes) contains appName
  end is_running

  set was_running to is_running("Messages")

  tell application "Messages"
    set targetService to 1st service whose service type = iMessage
    set targetBuddy to buddy "$imessage_address" of targetService
    send "Pôle emploi : $nouveaux_courriers_telecharges $texte" to targetBuddy
  end tell

  if was_running is not true then
    quit app "Messages"
  end if
END
    fi
  fi

  if [ $config[shut_up] = false ]; then
    # Heck let's even SAY it if the computer can !
    if hash say 2>/dev/null;
    then
        say "Alerte pôle-emploi !"
        say "$nouveaux_courriers_telecharges $texte"
    fi
  fi

else

  # CASE 2: we correctly got a PDF list, but no new PDF was found
  # -------------------------------------------------------------

  # Store & print output
  output="${BOLD_BLUE}[OK]${RESET} %BAucun nouveau courrier n'a été trouvé%b"
  print -P $output
fi

# Delete cookies ?! http://img12.deviantart.net/d497/i/2015/287/8/5/cookie_monster_____by_supergecko99-d9d2smd.png
rm cookies.txt
