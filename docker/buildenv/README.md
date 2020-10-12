#  MISP2 Docker compilation &  development run environment

These Dockerfiles are for containers that can be used for building and running the original MISP2 delivery.

## Usage

Clone following projects into the work directory: 
    
 - misp2-install-source
 - misp2-orbeon-war
 - misp2-web-app
  

*Note:* Following commands are to be executed in the directory where the projects referred above are cloned.

### Build the docker image for building the MISP2 packages:

      
    $ docker  build   --tag misp2-builder  ./misp2-install-source/docker/buildenv  
    
### Build misp2 packages using this: 

    $ docker run --name=misp2-build-env --volume=$(pwd):/home/builder/misp2  misp2-builder build_misp2_packages.sh
    
 
     
### Clean old images: 

    $ docker ps -aq  -f "ancestor=misp2-builder" | xargs docker rm  ; docker image rm misp2-builder  

### Clean created misp2 packages: 

    $ rm -rf ./misp2-install-sources/repo/dists ./misp2-install-sources/repo-unsigned/*  

    
  