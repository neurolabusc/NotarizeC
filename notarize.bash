#!/bin/bash
set -e

CODE_SIGN_SIGNATURE="Developer ID Application"
APPLE_ID_USER=name@email.com
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
EXECUTABLE_NAME=hello
BUNDLE_ID=com.mycompany.hello

# run cmake
echo "Building"
cd hello
mkdir -p build
cd build
cmake ..
make

# copy executable to bin
mkdir -p bin
cp hello bin/hello
cd bin

# Clean up temporary files
rm -f ${EXECUTABLE_NAME}_macOS.dmg
rm -f ${EXECUTABLE_NAME}_macOS.tmp.dmg
rm -f upload_log_file.txt
rm -f request_log_file.txt
rm -f log_file.txt

# Verify the Info.plist was embedded in the executable during linking
echo "Verifying Info.plist"
launchctl plist $EXECUTABLE_NAME

# Codesign the executable by enabling the hardened runtime (--options=runtime) and include a timestamp (--timestamp)
echo "Code signing..."
codesign -vvv --force --strict --options=runtime --timestamp -s "$CODE_SIGN_SIGNATURE" $EXECUTABLE_NAME
codesign --verify --verbose --strict $EXECUTABLE_NAME

# We need to distrubute the executable in a disk image because the stapler only works with directories
echo "Creating disk image..."
hdiutil create -volname $EXECUTABLE_NAME -srcfolder `pwd` -ov -format UDZO -layout SPUD -fs HFS+J  ${EXECUTABLE_NAME}_macOS.tmp.dmg
hdiutil convert ${EXECUTABLE_NAME}_macOS.tmp.dmg -format UDZO -o ${EXECUTABLE_NAME}_macOS.dmg

# Notarizing with Apple...
echo "Uploading..."
xcrun altool --notarize-app -t osx --file ${EXECUTABLE_NAME}_macOS.dmg --primary-bundle-id $BUNDLE_ID -u $APPLE_ID_USER -p $APP_SPECIFIC_PASSWORD --output-format xml > upload_log_file.txt

# WARNING: if there is a 'product-errors' key in upload_log_file.txt something went wrong
# TODO: parse out the error instead of exiting the script (remember set -e is enabled)
# /usr/libexec/PlistBuddy -c "Print :product-errors:0:message" upload_log_file.txt

# now we need to query apple's server to the status of notarization
# when the "xcrun altool --notarize-app" command is finished the output plist
# will contain a notarization-upload->RequestUUID key which we can use to check status
echo "Checking status..."
sleep 20
REQUEST_UUID=`/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" upload_log_file.txt`
while true; do
  xcrun altool --notarization-info $REQUEST_UUID -u $APPLE_ID_USER -p $APP_SPECIFIC_PASSWORD --output-format xml > request_log_file.txt
  # parse the request plist for the notarization-info->Status Code key which will
  # be set to "success" if the package was notarized
  STATUS=`/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" request_log_file.txt`
  if [ "$STATUS" != "in progress" ]; then
    break
  fi
  # echo $STATUS
  echo "$STATUS"
  sleep 10
done

# download the log file to view any issues
/usr/bin/curl -o log_file.txt `/usr/libexec/PlistBuddy -c "Print :notarization-info:LogFileURL" request_log_file.txt`

# staple
echo "Stapling..."
xcrun stapler staple ${EXECUTABLE_NAME}_macOS.dmg
xcrun stapler validate ${EXECUTABLE_NAME}_macOS.dmg

# open the log file so we can see if there are any warnings or other issues
open log_file.txt
