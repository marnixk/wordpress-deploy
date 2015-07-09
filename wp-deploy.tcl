#!/usr/bin/tclsh

# Example invocation:
# 
#     GIT_ROOT=/data/code/your_wp_project \
#     VERSION_FOLDER=versions/ \
#     VHOST_FILE=vhosts.conf \
#     HOST_ROOT=dev.yourdomain.com \
#     PASS_FILE=/etc/users-file \
#     UPLOAD_FOLDER=./uploads \
#     ARCHIVE_FOLDER=archives/ wp-deploy.tcl
# 
# Prerequisites:
# 	* wp-config.php and wp-content/upload set as 'export-ignore' in .gitattributes
# 	* folder has wp-config.php in it (wordpress by default searches up one folder if it can't find it in source tree)
# 
# Calling the wp deploy script like this will:
# 	
# 	* get all branches and tags from $GIT_ROOT
# 	* create archives of each and put them in $ARCHIVE_FOLDER
# 	* extracts all archives into $VERSION_FOLDER
# 	* makes a symlink from $UPLOAD_FOLDER to each archive's wp-content/upload
# 	* generates a virtualhost file at $VHOST_FILE
# 	* only users specified in $PASS_FILE can access the virtual hosts
# 	* the virtual hosts are set to `<branch/tagname>.$HOST_ROOT`
# 


#
#	Will fast fail if certain environment variables are missing
#
set working_dir [file normalize .]
set git_root [file normalize $env(GIT_ROOT)]
set version_folder [file normalize $env(VERSION_FOLDER)]
set archive_folder [file normalize $env(ARCHIVE_FOLDER)]
set vhost_file [file normalize $env(VHOST_FILE)]
set pass_file [file normalize $env(PASS_FILE)]
set upload_folder [file normalize $env(UPLOAD_FOLDER)]
set host_root $env(HOST_ROOT)

proc get_tags {folder} {
	set cwd [pwd]
	cd $folder
	set tags [exec git tag]
	cd $cwd

	return $tags
}


proc get_branches {folder} {
	set cwd [pwd]
	cd $folder
	set branches [exec git branch --no-color]
	cd $cwd

	lappend branchNames
	set lines [split $branches \n]
	foreach line $lines {
		lappend branchNames [string range $line 2 end]
	}

	return $branchNames
}


proc export_to {gitFolder archiveFolder branchName} {
	set cwd [pwd]
	cd $gitFolder
	exec git archive $branchName -o $archiveFolder/$branchName.tar.gz --prefix=$branchName/
	cd $cwd
}


# get all branches
set branchNames [get_branches $git_root]

# get all tags
set tags [get_tags $git_root]

# concatenate the two
set items [concat $branchNames $tags]

# export into archives
lappend archiveFiles
foreach branch $items {
	puts "Exporting branch/tag: $branch"
	export_to $git_root $archive_folder $branch
	lappend archiveFiles "$archive_folder/$branch.tar.gz"
}


# unpack all archives into version_folder
cd $version_folder
foreach archive $archiveFiles {
	puts -nonewline "Unpacking version: $archive .. "
	exec tar -xvzf $archive 
	puts "done!"
}

# setup wp-content/uploads folder symlink
foreach folder [glob *] {
	puts "Linking content folder for `$folder`"
	exec ln -s $upload_folder $folder/wp-content/uploads
}

cd $working_dir

# create virtual host string
set vhost ""

foreach item $items {
	append vhost [subst -nocommands {
		<VirtualHost *:80>
				ServerAdmin webmaster@localhost
				ServerName $item.$host_root

				DocumentRoot $version_folder/$item

				<Directory $version_folder/$item>
						<IfModule mod_rewrite.c>
								RewriteEngine On
								RewriteBase /
								RewriteRule ^index\.php$ - [L]
								RewriteCond %{REQUEST_FILENAME} !-f
								RewriteCond %{REQUEST_FILENAME} !-d
								RewriteRule . /index.php [L]
						</IfModule>

						Options +Indexes +FollowSymLinks +MultiVIews +Includes
						AllowOverride None

						AuthType Basic
						AuthName "Realm Authentication"
						AuthUserFile $pass_file
						Require valid-user
				</Directory>

				ErrorLog \${APACHE_LOG_DIR}/error.log
				CustomLog \${APACHE_LOG_DIR}/access.log combined

				LogLevel info
		</VirtualHost>

	}]
}

# write hostfile
set vhostFp [open $vhost_file "w"]
puts $vhostFp $vhost
close $vhostFp