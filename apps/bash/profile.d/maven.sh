# profile.d/maven.sh -- Apache Maven.
# shellcheck shell=bash
# Maven 3.6+ no longer needs M2_HOME, but Java IDEs and some tools still read it.
MAVEN_VERSION="3.9.6"
export M2_HOME="/opt/apache-maven-${MAVEN_VERSION}"
path::append "$M2_HOME/bin"
