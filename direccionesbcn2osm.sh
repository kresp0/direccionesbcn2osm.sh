#!/bin/bash
# Descarga, transforma y reproyecta las direcciones de Barcelona
# a partir los datos abiertos del Ajuntament al formato XML de OSM.
# Santiago Crespo 2016 
# https://creativecommons.org/publicdomain/zero/1.0/

OUT_FILE=direcciones-BCN.osm
TMPDIR=/tmp/direcciones-bcn
ORIG_PWD="$PWD"

rm -rf $TMPDIR
mkdir $TMPDIR
cd $TMPDIR

# Download the rdf with the source:date information:
wget "http://opendata.bcn.cat/opendata/es/catalog/SECTOR_PUBLIC/data-catalog/0/RDF" -O rdf
FECHA_CALLES=`grep -A 3 CARRERER rdf | grep "dct:modified" | awk -F '>' '{print $2}' | awk -F 'T' '{print $1}'`
FECHA_DIRECCIONES=`grep -A3 INFRAESTRUCTURES/TAULA_DIRELE rdf | grep "dct:modified" | awk -F '>' '{print $2}' | awk -F 'T' '{print $1}'`

if [ "$a" != "$b" ]; then
  echo "ERROR: FECHA_CALLES y FECHA_DIRECCIONES no coinciden!"
  echo "FECHA_CALLES = $FECHA_CALLES"
  echo "FECHA_DIRECCIONES = $FECHA_DIRECCIONES"
  echo "No sé que poner en source:date"
  exit 1
fi

# Download the csv file with the addresses
wget http://opendata.bcn.cat/opendata/es/catalog/URBANISME_I_INFRAESTRUCTURES/tauladirele/ -O direcciones.html
wget `grep csv direcciones.html | grep http | awk -F '"' '{print "http://opendata.bcn.cat"$2}'` -O TAULA_DIRELE.csv

perl -pe 's/ETRS89_COORD_X/x/g' TAULA_DIRELE.csv | perl -pe 's/ETRS89_COORD_Y/y/g' > t ; mv t TAULA_DIRELE.csv

# Reproject from EPSG:25831 to EPSG:4326:
echo '<OGRVRTDataSource>
  <OGRVRTLayer name="TAULA_DIRELE">
  <SrcDataSource>TAULA_DIRELE.csv</SrcDataSource>
  <GeometryType>wkbPoint</GeometryType>
  <LayerSRS>+init=epsg:25831 +wktext</LayerSRS>             
  <GeometryField encoding="PointFromColumns" x="x" y="y"/>
  </OGRVRTLayer>
  </OGRVRTDataSource>' > direcciones-bcn.vrt

ogr2ogr -lco GEOMETRY=AS_XY -overwrite -f CSV -t_srs EPSG:4326 DIRECCIONES-BCN.csv direcciones-bcn.vrt

# Download the csv file with the complete street names
wget http://opendata.bcn.cat/opendata/es/catalog/URBANISME_I_INFRAESTRUCTURES/taulacarrers/ -O calles.html
wget `grep csv calles.html | grep http | awk -F '"' '{print "http://opendata.bcn.cat"$2}'` -O CARRERER.csv

# Remove the first line
tail -n +2 DIRECCIONES-BCN.csv > t ; mv t DIRECCIONES-BCN.csv
tail -n +2 CARRERER.csv > t ; mv t CARRERER.csv

# Add headers
echo '<?xml version="1.0" encoding="UTF-8"?>' > $OUT_FILE
echo '<osm version="0.6" generator="direccionesbcn2osm.sh 1.0">' >> $OUT_FILE

COUNTER=0

while IFS=$';' read -r -a VIA; do
  echo "Procesando: ${VIA[3]}"

  while IFS=$',' read -r -a DIRECCIONES; do
# Si CODI_VIA es = CODI_CARRER
    if [ "${VIA[0]}" = "${DIRECCIONES[2]}" ]; then
      let COUNTER=COUNTER-1
      echo '  <node id="'$COUNTER'" lat="'${DIRECCIONES[1]}'" lon="'${DIRECCIONES[0]}'">' >> $OUT_FILE
      echo '    <tag k="ajbcn:street_id" v="'${DIRECCIONES[2]}'"/>' >> $OUT_FILE
########## TODO: JUNTAR NÚMERO Y LETRA SI TIENE LETRA
      echo '    <tag k="addr:street" v="'${VIA[3]}'"/>' >> $OUT_FILE
      NUMERO=$(echo ${DIRECCIONES[3]} | sed 's/^0*//') # Remove leading zeroes
      echo $NUMERO
	  echo '    <tag k="addr:housenumber" v="'$NUMERO'"/>' >> $OUT_FILE
	  echo '    <tag k="addr:postcode" v="080'${DIRECCIONES[7]}'"/>' >> $OUT_FILE
      echo '    <tag k="source" v="Ajuntament de Barcelona"/>' >> $OUT_FILE
      echo '    <tag k="source:date" v="'$FECHA_DIRECCIONES'"/>' >> $OUT_FILE
#      echo '    <tag k="source" v="Infraestructura de dades espacials de l\'Ajuntament de Barcelona - Geoportal"/>' >> $OUT_FILE
#      echo '    <tag k="source" v="Carto BCN / Ajuntament de Barcelona"/>' >> $OUT_FILE
      echo '  </node>' >> $OUT_FILE
    fi
  done < $TMPDIR/DIRECCIONES-BCN.csv

done < $TMPDIR/CARRERER.csv

echo '</osm>' >> $OUT_FILE
