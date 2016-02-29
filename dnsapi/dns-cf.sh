#!/bin/bash


#
#CF_Key="sdfsdfsdfljlbjkljlkjsdfoiwje"
#
#CF_Email="xxxx@sss.com"


CF_Api="https://api.cloudflare.com/client/v4/"

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns-cf-add() {
  fulldomain=$1
  txtvalue=$2
  
  if [ -z "$CF_Key" ] || [ -z "$CF_Email" ] ; then
    _err "You don't specify cloudflare api key and email yet."
    _err "Please create you key and try again."
    return 1
  fi
  
  #save the api key and email to the account conf file.
  _saveaccountconf CF_Key "$CF_Key"
  _saveaccountconf CF_Email "$CF_Email"
  
  _debug "First detect the root zone"
  if ! _get_root $fulldomain ; then
    _err "invalid domain"
    return 1
  fi
  _debug _domain_id "$_domain_id"
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"
  
  _debug "Getting txt records"
  _cf_rest GET "/zones/${_domain_id}/dns_records?type=TXT&name=$fulldomain"
  
  if [ "$?" != "0" ] || ! printf $response | grep \"success\":true > /dev/null ; then
    _err "Error"
    return 1
  fi
  
  count=$(printf $response | grep -o \"count\":[^,]* | cut -d : -f 2)
  
  if [ "$count" == "0" ] ; then
    _info "Adding record"
    if _cf_rest POST "/zones/$_domain_id/dns_records"  "{\"type\":\"TXT\",\"name\":\"$fulldomain\",\"content\":\"$txtvalue\",\"ttl\":120}"; then
      if printf $response | grep $fulldomain > /dev/null ; then
        _info "Added, sleeping 10 seconds"
        sleep 10
        #todo: check if the record takes effect
        return 0
      else
        _err "Add txt record error."
        return 1
      fi
    fi
    _err "Add txt record error."
  else
    _info "Updating record"
    record_id=$(printf $response | grep -o \"id\":\"[^\"]*\" | cut -d : -f 2 | tr -d \")
    _debug "record_id" $record_id
    
    _cf_rest PUT "/zones/$_domain_id/dns_records/$record_id"  "{\"id\":\"$record_id\",\"type\":\"TXT\",\"name\":\"$fulldomain\",\"content\":\"$txtvalue\",\"zone_id\":\"$_domain_id\",\"zone_name\":\"$_domain\"}"
    if [ "$?" == "0" ]; then
      _info "Updated, sleeping 10 seconds"
      sleep 10
      #todo: check if the record takes effect
      return 0;
    fi
    _err "Update error"
    return 1
  fi
  
}





####################  Private functions bellow ##################################
#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
# _domain_id=sdjkglgdfewsdfg
_get_root() {
  domain=$1
  i=2
  p=1
  while [ '1' ] ; do
    h=$(printf $domain | cut -d . -f $i-100)
    if [ -z "$h" ] ; then
      #not valid
      return 1;
    fi
    
    if ! _cf_rest GET "zones?name=$h" ; then
      return 1
    fi
    
    if printf $response | grep \"name\":\"$h\" ; then
      _domain_id=$(printf "$response" | grep -o \"id\":\"[^\"]*\" | head -1 | cut -d : -f 2 | tr -d \")
      if [ "$_domain_id" ] ; then
        _sub_domain=$(printf $domain | cut -d . -f 1-$p)
        _domain=$h
        return 0
      fi
      return 1
    fi
    p=$i
    let "i+=1"
  done
  return 1
}


_cf_rest() {
  m=$1
  ep="$2"
  _debug $ep
  if [ "$3" ] ; then
    data="$3"
    _debug data "$data"
    response="$(curl --silent -X $m "$CF_Api/$ep" -H "X-Auth-Email: $CF_Email" -H "X-Auth-Key: $CF_Key" -H "Content-Type: application/json" --data $data)"
  else
    response="$(curl --silent -X $m "$CF_Api/$ep" -H "X-Auth-Email: $CF_Email" -H "X-Auth-Key: $CF_Key" -H "Content-Type: application/json")"
  fi
  
  if [ "$?" != "0" ] ; then
    _err "error $ep"
    return 1
  fi
  _debug response "$response"
  return 0
}


_debug() {

  if [ -z "$DEBUG" ] ; then
    return
  fi
  
  if [ -z "$2" ] ; then
    echo $1
  else
    echo "$1"="$2"
  fi
}

_info() {
  if [ -z "$2" ] ; then
    echo "$1"
  else
    echo "$1"="$2"
  fi
}

_err() {
  if [ -z "$2" ] ; then
    echo "$1" >&2
  else
    echo "$1"="$2" >&2
  fi
}


