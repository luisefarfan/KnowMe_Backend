const { ObjectId } = require('bson')
const express = require('express')
const router = express.Router()
const database = require('../config/database')
const md5 = require('md5')
const jwt = require('../config/jwt')

router.post('/nuevo', function(req, res, next) {
    if (req.body.email !== req.body.reEmail)
        return res.json({message: 'No coinciden los emails'})

    if (req.body.password !== req.body.rePassword)
        return res.json({message: 'No coinciden las contraseñas'})

    let nuevoUsuario = {
        nombre: req.body.nombre,
        apellido: req.body.apellido,
        telefono: req.body.telefono,
        fechaNacimiento: req.body.fechaNacimiento,
        email: req.body.email,
        username: req.body.username,
        password: md5(req.body.password),
        imagenPerfil: req.body.imagenPerfil
    }

    database.connect(function(err, client) {
        if (err) return res.json({message: 'Error al conectarse a la base de datos', error: err})

        const db = client.db('KnowMe')

        db.collection('Usuarios').findOne({
            email: nuevoUsuario.email
        }).then(result => {
            if (result) {
                client.close()
                return res.json({message: 'Ya existe un usuario con el correo ingresado'})
            }

            db.collection('Usuarios').insertOne(nuevoUsuario)
            .then(result => {
                if (result.result.ok !== 1) {
                    client.close()
                    return res.json({message: 'Error al insertar'})
                }
                client.close()
                const token = jwt.generateToken(nuevoUsuario.username)
                return res.status(201).json({usuario: nuevoUsuario, token: token})
            })
        })
    })
})

router.get('/', function(req, res, next) {
    database.connect(function(err, client) {
        if (err) return res.status(500).json({message: 'Error al conectarse a la base de datos'})

        const db = client.db('KnowMe')

        db.collection('Usuarios').find().toArray((err, result) => {
            console.log(result)
            client.close()
            return res.status(201).json({usuarios: result})
        })
    })
})

router.get('/:id', function(req, res, next) {
    database.connect(function(err, client) {
        if (err) return res.status(500).json({message: 'Error al conectarse a la base de datos'})

        const db = client.db('KnowMe')
        const query = {
            _id: ObjectId(req.params.id)
        }

        db.collection('Usuarios').findOne(query).then(result => {
            if (!result) {
                client.close()
                return res.status(500).json({message: 'No se encontro el usuario'})
            }
            console.log(result)
            client.close()
            return res.status(201).json({usuario: result})
        })
    })
})

router.put('/:id', function(req, res, next) {
    database.connect(function(err, client) {
        if (err) return res.status(500).json({message: 'Error al conectarse a la base de datos'})

        const db = client.db('KnowMe')
        const query = {
            _id: ObjectId(req.params.id)
        }

        db.collection('Usuarios').findOneAndUpdate(
            {
                _id: ObjectId(req.params.id)
            },
            {
                $set: {
                    nombre: req.body.nombre,
                    apellido: req.body.apellido,
                    telefono: req.body.telefono,
                    fechaNacimiento: req.body.fechaNacimiento,
                    email: req.body.email,
                    username: req.body.username,
                    password: req.body.password
                }
            },
            {
                returnOriginal: false
            }
        ).then(result => {
            if (!result) {
                client.close()
                return res.status(500).json({message: 'No se encontro el usuario'})
            }
            console.log(result.value)
            client.close()
            return res.status(202).json({usuario: result.value})
        })
    })
})

router.delete('/:id', function(req, res, next) {
    database.connect(function(err, client) {
        if (err) return res.status(500).json({message: 'Error al conectarse a la base de datos'})

        const db = client.db('KnowMe')
        const query = {
            _id: ObjectId(req.params.id)
        }

        db.collection('Usuarios').findOneAndDelete(
            {
                _id: ObjectId(req.params.id)
            }
        ).then(result => {
            console.log(result)
            if (!result.ok) {
                client.close()
                return res.status(500).json({message: 'Error'})
            }
            client.close()
            return res.status(204).json({usuario: result})
        })
    })
})

module.exports = router