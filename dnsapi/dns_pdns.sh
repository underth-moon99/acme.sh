#!/usr/bin/env sh

#PowerDNS Emdedded API
#https://doc.powerdns.com/md/httpapi/api_spec/
#
#PDNS_Url="http://ns.example.com:8081"
#PDNS_ServerId="localhost"
#PDNS_Token="0123456789ABCDEF"
#PDNS_Ttl=60

DEFAULT_PDNS_TTL=60

########  Public functions #####################
#Usage: add _acme-challenge.www.domain.com "123456789ABCDEF0000000000000000000000000000000000000"
dns_pdns_add() {
  fulldomain=$1
  txtvalue=$2

  if [ -z "$PDNS_Url" ]; then
    _err "You don't specify PowerDNS address."
    _err "Please set PDNS_Url and try again."
    return 1
  fi

  if [ -z "$PDNS_ServerId" ]; then
    _err "You don't specify PowerDNS server id."
    _err "Please set you PDNS_ServerId and try again."
    return 1
  fi

  if [ -z "$PDNS_Token" ]; then
    _err "You don't specify PowerDNS token."
    _err "Please create you PDNS_Token and try again."
    return 1
  fi

  if [ -z "$PDNS_Ttl" ]; then
    PDNS_Ttl=$DEFAULT_PDNS_TTL
  fi

  #save the api addr and key to the account conf file.
  _saveaccountconf PDNS_Url "$PDNS_Url"
  _saveaccountconf PDNS_ServerId "$PDNS_ServerId"
  _saveaccountconf PDNS_Token "$PDNS_Token"

  if [ "$PDNS_Ttl" != "$DEFAULT_PDNS_TTL" ]; then
    _saveaccountconf PDNS_Ttl "$PDNS_Ttl"
  fi

  _debug "First detect the root zone"
  if ! _get_root $fulldomain; then
    _err "invalid domain"
    return 1
  fi
  _debug _domain "$_domain"

  if ! set_record "$_domain" "$fulldomain" "$txtvalue"; then
    return 1
  fi

  return 0
}

#fulldomain
dns_pdns_rm() {
  fulldomain=$1

}

set_record() {
  _info "Adding record"
  root=$1
  full=$2
  txtvalue=$3

  if ! _pdns_rest "PATCH" "/api/v1/servers/$PDNS_ServerId/zones/$root." "{\"rrsets\": [{\"name\": \"$full.\", \"changetype\": \"REPLACE\", \"type\": \"TXT\", \"ttl\": $PDNS_Ttl, \"records\": [{\"name\": \"$full.\", \"type\": \"TXT\", \"content\": \"\\\"$txtvalue\\\"\", \"disabled\": false, \"ttl\": $PDNS_Ttl}]}]}"; then
    _err "Set txt record error."
    return 1
  fi
  if ! _pdns_rest "PUT" "/api/v1/servers/$PDNS_ServerId/zones/$root./notify"; then
    _err "Notify servers error."
    return 1
  fi
  return 0
}

####################  Private functions bellow ##################################
#_acme-challenge.www.domain.com
#returns
# _domain=domain.com
_get_root() {
  domain=$1
  i=1
  p=1

  if _pdns_rest "GET" "/api/v1/servers/$PDNS_ServerId/zones"; then
    _zones_response=$response
  fi

  while [ '1' ]; do
    h=$(printf $domain | cut -d . -f $i-100)
    if [ -z "$h" ]; then
      return 1
    fi

    if printf "$_zones_response" | grep "\"name\": \"$h.\"" >/dev/null; then
      _domain=$h
      return 0
    fi

    p=$i
    i=$(expr $i + 1)
  done
  _debug "$domain not found"
  return 1
}

_pdns_rest() {
  method=$1
  ep=$2
  data=$3

  _H1="X-API-Key: $PDNS_Token"

  if [ ! "$method" = "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$PDNS_Url$ep" "" "$method")"
  else
    response="$(_get "$PDNS_Url$ep")"
  fi

  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"

  return 0
}
