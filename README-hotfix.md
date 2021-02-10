
# MISP2 application hotfix release 2.5.0


## Features: 

  * Improved compliancy with SK-EID Secure Implementation Guide 
     /1/

## Intended audience

This release is beneficial only for these MISP2 installations where users are authenticated with *ID-Card authentication*. 

## Release testing

Basic testing has been done for this hotfix on Ubuntu 18.04 and 16.04 platforms.


## Installation

Installation of the release is done according to the MISP2 Installation manual 
/2/ with following minor exceptions. 

### EXCEPTIONS TO THE STANDARD INSTALLATION:

#### Chapter 3.1. 

Updating the MISP2 package list, first box, you  should instead use the following cmd:


     echo "deb [arch=amd64] https://artifactory.niis.org/xroad-extensions-release-deb/ bionic main" >> /etc/apt/sources.list.d/misp.list

#### Chapter 3.2    

No updates are needed for the xtee-misp2-postgresql package, so you can skip chapter 3.2. MISP2 database installation.

#### Chapter 3.3  

Before the first instructed command you need give command:

     apt-get install  -y xtee-misp2-base

and then proceed.

#### Chapter 3.3.1 : 

You must answer Y  to the prompts:

    

     Do you want to overwrite Apache2 configuration with default settings? [y/n] [default: n]:   Y

 and

     Do you want to update the SK certificates (y/n)?  [y]  Y

 
### Custom Apache2 configurations

If customer has done changes to the file

     /etc/apache2/sites-enabled/ssl.conf

more than the manual-instructed IP-address addition for  the admin UI access, customer needs to add one more line after line

     <VirtualHost *:443>
     ....

The line to add is:

     SSLCADNRequestPath /etc/apache2/ssl/client_ca/





 ## References

 /1/ Secure Implementation Guide  - 
     https://github.com/SK-EID/smart-id-documentation/wiki/Secure-Implementation-Guide#only-accept-certificates-with-trusted-issuance-policy

/2/ MISP2 Installation manual  - See your original MISP2 delivery

