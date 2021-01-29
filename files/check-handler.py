#!/usr/bin/env python3
import json, sys, requests
from requests.auth import HTTPBasicAuth
def main():
  amq_url = "http://amq_public_address:8161/api/message/consul.checks?type=topic"
  consul_watch = json.load(sys.stdin)
  for i in consul_watch:
    check_info = {
            "Node": i['Node'],
            "Check": i['CheckID'],
            "Status": i['Status']
            }
    check_json = json.dumps(check_info)
    print(check_json)
    requests.post(amq_url, json=check_json, auth=HTTPBasicAuth('admin', 'admin'))
if __name__ == "__main__":
  main()