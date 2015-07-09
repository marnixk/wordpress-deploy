# Wordpress Deploy script


Example invocation:

    GIT_ROOT=/data/code/your_wp_project \
    VERSION_FOLDER=versions/ \
    VHOST_FILE=vhosts.conf \
    HOST_ROOT=dev.yourdomain.com \
    PASS_FILE=/etc/users-file \
    UPLOAD_FOLDER=./uploads \
    ARCHIVE_FOLDER=archives/ wp-deploy.tcl

Prerequisites:

* wp-config.php and wp-content/upload set as 'export-ignore' in .gitattributes
* folder has wp-config.php in it (wordpress by default searches up one folder if it can't find it in source tree)

Calling the wp deploy script like this will:
	
* get all branches and tags from $GIT_ROOT
* create archives of each and put them in $ARCHIVE_FOLDER
* extracts all archives into $VERSION_FOLDER
* makes a symlink from $UPLOAD_FOLDER to each archive's wp-content/upload
* generates a virtualhost file at $VHOST_FILE
* only users specified in $PASS_FILE can access the virtual hosts
* the virtual hosts are set to `<branch/tagname>.$HOST_ROOT`