#------------------------------------------------------------#
# Docker file for an MDI engine
#------------------------------------------------------------#

FROM mdi/base

# copy the build script
COPY .temp/build_image.sh .

# run the build script
RUN bash build_image.sh
