curl localhost:5000/crank \
    -X POST \
    --verbose \
    --data "format=commutative-diagrams-livedemo" \
    --data "template=latex-minimal" \
    --data "document=Hello+world!"
