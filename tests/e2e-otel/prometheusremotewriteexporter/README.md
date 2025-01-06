# Generate certs
The example certs were generated with the following commands:

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout ca.key -out ca.crt -subj '/CN=MyDemoCA'
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout cert.key -out cert.crt -CA ca.crt -CAkey ca.key -subj "/CN=prometheus" -addext "subjectAltName=DNS:prometheus"

oc create secret generic prometheus-ca --from-file=ca.crt -n NAMESPACE
oc create secret tls prometheus-certs --cert=cert.crt --key=cert.key -n NAMESPACE