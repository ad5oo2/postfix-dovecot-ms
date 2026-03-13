import os
import shutil
import mysql.connector

mydb = mysql.connector.connect(
  host=os.environ.get('MYSQL_SERVER'),
  user=os.environ.get('MYSQL_USER'),
  password=os.environ.get('MYSQL_PASSWORD'),
  database=os.environ.get('MYSQL_DB')
)

maildir = os.environ.get('MAILDIR_BASE')

sql_emails = []
mycursor = mydb.cursor()
mycursor.execute("SELECT email FROM virtual_users")
myresult = mycursor.fetchall()
for email in myresult:
  sql_emails.append(email[0])

folders = []
mailbase = os.listdir(maildir)
for domain in mailbase:
  domainlist = os.listdir(maildir+domain)
  for email in domainlist:
    folders.append(email+'@'+domain)

remove_folders = []

for folder in folders:
  if not (folder in sql_emails):
    remove_folders.append(folder)

for folder in remove_folders:
  rmd = folder.split("@")
  removedir = maildir+rmd[1]+'/'+rmd[0]
  shutil.rmtree(removedir)
