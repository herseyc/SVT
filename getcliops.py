# Code snippet to get cli opts in python
import getopt

#Clear variables
ovc = ''
username = ''
password = ''
​sourcevm = ''

#Get sourcevm and clonevm from command line args
try:
   opts, args = getopt.getopt(sys.argv[1:],"hs:u:p:o:",["sourcevm=","username=","password=","ovc="])
except getopt.GetoptError:
   print 'SVTVMbackupReport.py -s <sourcevm> -u <username> -p <password> -o <OVCIP>'
   sys.exit(2)
for opt, arg in opts:
   if opt == '-h':
      print 'SVTVMbackupReport.py -s <sourcevm> -u <username> -p <password> -o <OVCIP>'
      sys.exit()
   elif opt in ("-s", "--sourcevm"):
      sourcevm = arg
   elif opt in ("-u", "--username"):
      username = arg
   elif opt in ("-p", "--password"):
      password = arg
   elif opt in ("-o", "--ovc"):
      ovc = arg

print 'Source VM is: ', sourcevm
print 'Username is: ', username
print 'Password is: ', password
print 'OVC is: ', ovc
