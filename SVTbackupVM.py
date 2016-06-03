##################################################################
# Use Python (pyCurl) and the SimpliVity REST API to backup a VM
# Usage: SVTbackupVM.py -s SOURCEVM 
#
# http://www.vhersey.com/
# 
# http://www.simplivity.com/
#
##################################################################
import pycurl
import json
import base64
import urllib
from io import BytesIO
import requests
import sys, getopt
import datetime, time

#IP or Hostname of OVC
ovc = 'OVC_IP'
#Username and Password
username = 'DEMO\AESOMEADMIN'
password = 'AWESOMEADMINPASSWORD'

#Clear sourcevm 
sourcevm = ''

#Get sourcevm from command line args
try:
   opts, args = getopt.getopt(sys.argv[1:],"hs:",["sourcevm="])
except getopt.GetoptError:
   print 'SVTVMbackupReport.py -s <sourcevm>'
   sys.exit(2)
for opt, arg in opts:
   if opt == '-h':
      print 'SVTVMbackupReport.py -s <sourcevm>'
      sys.exit()
   elif opt in ("-s", "--sourcevm"):
      sourcevm = arg

print 'Source VM is: ', sourcevm


#Fuction using pyCurl to post to SVT REST using url encoded data
def post_SVTREST(url, data, header):
   rdata = BytesIO()
   pdata = urllib.urlencode(data)
   c = pycurl.Curl()
   c.setopt(pycurl.SSL_VERIFYPEER, 0)
   c.setopt(pycurl.SSL_VERIFYHOST, 0)
   c.setopt(pycurl.URL, url)
   c.setopt(pycurl.HTTPHEADER, header)
   c.setopt(c.WRITEFUNCTION, rdata.write)
   c.setopt(pycurl.POST, 1)
   c.setopt(pycurl.POSTFIELDS, pdata)
   c.perform()
   c.close()
   jdata = json.loads(rdata.getvalue())
   return (jdata)

#Fuction using pyCurl to post to SVT REST using json data
def jpost_SVTREST(url, data, header):
   rdata = BytesIO()
   c = pycurl.Curl()
   c.setopt(pycurl.SSL_VERIFYPEER, 0)
   c.setopt(pycurl.SSL_VERIFYHOST, 0)
   c.setopt(pycurl.URL, url)
   c.setopt(pycurl.HTTPHEADER, header)
   c.setopt(c.WRITEFUNCTION, rdata.write)
   c.setopt(pycurl.POST, 1)
   c.setopt(pycurl.POSTFIELDS, data)
   c.perform()
   c.close()
   jdata = json.loads(rdata.getvalue())
   return (jdata)

#Funtion using pyCurl to get from SVT REST
def get_SVTREST(url, header):
   rdata = BytesIO()
   c = pycurl.Curl()
   c.setopt(pycurl.SSL_VERIFYPEER, 0)
   c.setopt(pycurl.SSL_VERIFYHOST, 0)
   c.setopt(pycurl.URL, url)
   c.setopt(pycurl.HTTPHEADER, header)
   c.setopt(c.WRITEFUNCTION, rdata.write)
   c.perform()
   c.close()
   jdata = json.loads(rdata.getvalue())
   return (jdata)

#Get Access Token
url = 'https://'+ ovc +'/api/oauth/token'
data = {'username': username,'password': password,'grant_type':'password'}
svtuser = 'simplivity:'
svtauth = 'Authorization:  Basic ' + base64.b64encode(svtuser)
htoken = ['Accept: application/json', svtauth ]
svttoken = post_SVTREST(url, data, htoken)
accesstoken = 'Authorization: Bearer ' + svttoken["access_token"]

#Get VM Id of Source VM
htoken = ['Accept: application/json', accesstoken]
url = 'https://'+ ovc +'/api/virtual_machines?show_optional_fields=false&name=' +  sourcevm
SVTvms = get_SVTREST(url, htoken)
vm_id = SVTvms['virtual_machines'][0]['id']
cluster_id = SVTvms['virtual_machines'][0]['omnistack_cluster_id']

#GetDateTime
d = datetime.datetime.fromtimestamp(time.time())
dstamp =  sourcevm + "-RESTBU-" + d.strftime("%d%m%y%H%M%S") 

#Backup the Source VM
url = 'https://'+ ovc +'/api/virtual_machines/'+ vm_id +'/backup'
data = {"app_consistent": "false", "backup_name": dstamp, "destination_id": cluster_id,"retention": 0}
sdata = json.dumps(data)
htoken = ['Accept: application/json', 'Content-Type: application/vnd.simplivity.v1+json', accesstoken ]
vmbackup = jpost_SVTREST(url, sdata, htoken)

#Report task details
print 'SimpliVity Backup ', vmbackup['task']['state']
print 'SVT Task Id: ', vmbackup['task']['id']














