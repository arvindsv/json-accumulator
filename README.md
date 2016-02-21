### An accumulator for JSON data:

This a reasonably thin wrapper over CouchDB, to be used by a generic accumulator of JSON data by various other apps of
mine.

##### Add data:

Add some data to a made-up repository called "db1":

```
$ curl -X POST http://json-accumulator-server/db1 --data-binary '{ "url": "http://abc.def/ghi", "value": 123 }'
{"ok":true,"id":"d4065640-0491-4fc8-9936-39bf9c8ba722","rev":"1-da3749518b17e0d7bd369bbba18ee7c8"}

$ curl -X POST http://json-accumulator-server/db1 --data-binary '{ "url": "http://aaa.com/abc", "value": 456 }'
{"ok":true,"id":"30a0685e-7f8b-4e0e-860e-11f3e040cf92","rev":"1-f0f16176deaecb502e211a80b26486ec"}

$ curl -X POST http://json-accumulator-server/db1 --data-binary '{ "url": "http://bbb.com/def", "value": 789 }'
{"ok":true,"id":"e7c36d4d-db7c-433d-8d61-c85a084239d7","rev":"1-0f4ee5be091e34bfb0ba239c76d4d56d"}
```

This data does not need to follow any kind of a schema. It just needs to be valid JSON.


##### Get the latest data

```
$ curl -X GET http://server/db1/latest
{"url":"http://bbb.com/def","value":789}
```

##### Use CouchDB views

###### Add a CouchDB design document or two:

```
$ curl -X POST -d "function(doc) { emit(doc.content.url, doc.content.value); }" http://json-accumulator-server/db1/view/view1
{"ok":true,"id":"_design/db1","rev":"2-4d817c3af64768ead3b77e604f66198b"}

$ curl -X POST -d "function(doc) { emit(doc.content.value, doc.content.url); }" http://json-accumulator-server/db1/view/view2
{"ok":true,"id":"_design/db1","rev":"3-d97056cacc5dd236a1eaeadcf7d60795"}
```

Notice that all the data put by the user is in the `doc.content` node.


###### Query by view:

```
$ curl -s -X GET http://server/db1/view/view1 | jq .
[
  {
    "id": "30a0685e-7f8b-4e0e-860e-11f3e040cf92",
    "key": "http://aaa.com/abc",
    "value": 456
  },
  {
    "id": "d4065640-0491-4fc8-9936-39bf9c8ba722",
    "key": "http://abc.def/ghi",
    "value": 123
  },
  {
    "id": "e7c36d4d-db7c-433d-8d61-c85a084239d7",
    "key": "http://bbb.com/def",
    "value": 789
  }
]

$ curl -s -X GET http://server/db1/view/view2 | jq .
[
  {
    "id": "d4065640-0491-4fc8-9936-39bf9c8ba722",
    "key": 123,
    "value": "http://abc.def/ghi"
  },
  {
    "id": "30a0685e-7f8b-4e0e-860e-11f3e040cf92",
    "key": 456,
    "value": "http://aaa.com/abc"
  },
  {
    "id": "e7c36d4d-db7c-433d-8d61-c85a084239d7",
    "key": 789,
    "value": "http://bbb.com/def"
  }
]
```

Query by view and filter down by a key:

```
$ curl -s -X GET 'http://json-accumulator-server/db1/view/view1?key="http://aaa.com/abc"' | jq .
[
  {
    "id": "30a0685e-7f8b-4e0e-860e-11f3e040cf92",
    "key": "http://aaa.com/abc",
    "value": 456
  }
]

$ curl -s -X GET http://json-accumulator-server/db1/view/view2?key=123 | jq .
[
  {
    "id": "d4065640-0491-4fc8-9936-39bf9c8ba722",
    "key": 123,
    "value": "http://abc.def/ghi"
  }
]
```

Notice that string keys need to be quoted, in the URL.