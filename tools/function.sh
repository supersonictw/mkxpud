function usage {

	echo "Usage: 
 mkxpud <option> [<project codename>] - Image Generator for xPUD

Options:
	all		Execute the whole process of creating a project image
	clean		Removes most generated files
	image		Genreate image from the working directory
	test		Invoke 'QEMU' to test image with bundled kernel 
	help		Display this help

For further informations please refer to README file."
}

function setup {

	echo "[mkxpud] Setup Project: $1"
	MKXPUD_CODENAME=$1
	mkdir -p working/$MKXPUD_CODENAME
	mkdir -p deploy/$MKXPUD_CODENAME
	export MKXPUD_CONFIG=config/$MKXPUD_CODENAME.cookbook
	eval export `./tools/parser $MKXPUD_CONFIG config`

	## FIXME: alias cp='cp -rfpL --remove-destination'
	cp -rfpL --remove-destination skeleton/rootfs/ working/$MKXPUD_CODENAME/rootfs
	export MKXPUD_TARGET=working/$MKXPUD_CODENAME/rootfs
	echo "[mkxpud] Project Target: $MKXPUD_TARGET"

}

function install {

	echo "    Preparing recipes..."

	if [ "$MKXPUD_SKIP_APT" == 'false' ]; then
	for R in `./tools/parser $MKXPUD_CONFIG recipe`; do 
		for P in `./tools/parser package/recipe/$R.recipe package`; do
		PACKAGE="$PACKAGE $P"
		done
	done

	sudo apt-get install -y $PACKAGE
	fi

}

function strip {

	echo "    Stripping binaries..."
	## FIXME: alias cp='cp -rfpL --remove-destination'
	for R in `./tools/parser $MKXPUD_CONFIG recipe`; do 
		
		# action 
		eval `./tools/parser package/recipe/$R.recipe action`

		for S in binary data config overwrite; do
		
			for A in `./tools/parser package/recipe/$R.recipe $S`; do
	
			case $S in
				binary) 
						##  host
						cp -rfpL --remove-destination $A $MKXPUD_TARGET/$A
						## ldd-helper
						for i in `./tools/ldd-helper $A`; do 
							if [ `dirname $i` == '/usr/lib' ]; then 
							cp -rfpL --remove-destination $i $MKXPUD_TARGET/usr/lib ; 
							else cp -rfpL --remove-destination $i $MKXPUD_TARGET/lib ; fi
						done
					;;
				data) 
						## host 
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfpL --remove-destination $A $MKXPUD_TARGET/$A
					;;
				config) 
						## package/config/*
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfpL --remove-destination package/config/$A $MKXPUD_TARGET/$A
					;;
				overwrite) 
						## skeleton/overwrite/
						[ -d $MKXPUD_TARGET/`dirname $A` ] || mkdir -p $MKXPUD_TARGET/`dirname $A` 
						cp -rfp skeleton/overwrite/$A $MKXPUD_TARGET/$A
					;;
			esac 
			
			done 
		done 
		
	done

}

# post 
# FIXME: hook post scripts
function post {

	echo ""
	echo "[mkxpud] Post-install scripts"

	./tools/busybox-helper

}

# kernel 

function image {

	echo "[mkxpud] Generating image..."
	MKXPUD_CODENAME=$1
	MKXPUD_TARGET=working/$MKXPUD_CODENAME/rootfs
	cd $MKXPUD_TARGET
	find | cpio -H newc -o > ../../../deploy/$MKXPUD_CODENAME/rootfs.cpio
	cd -

	## FIXME: check format
	cat deploy/$MKXPUD_CODENAME/rootfs.cpio | gzip -9 > deploy/$MKXPUD_CODENAME/rootfs.gz
	du -h deploy/$MKXPUD_CODENAME/rootfs.gz

}
