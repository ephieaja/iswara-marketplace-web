/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // add field
  collection.fields.addAt(8, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text942461139",
    "max": 0,
    "min": 0,
    "name": "NamaToko",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text3240084976",
    "max": 0,
    "min": 0,
    "name": "Alamat",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(10, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text3847995303",
    "max": 0,
    "min": 0,
    "name": "Daerah",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(11, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text3595298386",
    "max": 0,
    "min": 0,
    "name": "NoWa",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(12, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text62789441",
    "max": 0,
    "min": 0,
    "name": "Organisasi",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(13, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text2331148764",
    "max": 0,
    "min": 0,
    "name": "Tingkat",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(14, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text3459462055",
    "max": 0,
    "min": 0,
    "name": "Majlis",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(15, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text2526964493",
    "max": 0,
    "min": 0,
    "name": "NoAnggota",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_")

  // remove field
  collection.fields.removeById("text942461139")

  // remove field
  collection.fields.removeById("text3240084976")

  // remove field
  collection.fields.removeById("text3847995303")

  // remove field
  collection.fields.removeById("text3595298386")

  // remove field
  collection.fields.removeById("text62789441")

  // remove field
  collection.fields.removeById("text2331148764")

  // remove field
  collection.fields.removeById("text3459462055")

  // remove field
  collection.fields.removeById("text2526964493")

  return app.save(collection)
})
