import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const registrarUsuarioDesdeSharePoint = functions.https.onRequest(
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Método no permitido. Usa POST.");
        return;
      }

      const {
        Título,
        antiguedad,
        apellidos,
        email,
        fechaIng,
        jefe,
        nombre,
        no,
        ns,
        privilegio,
        puesto,
        reporta,
        tipo,
        vacaciones,
      } = req.body;

      if (!Título || !nombre) {
        res.status(400).send("Faltan campos: 'no' o 'nombre'.");
        return;
      }

      const snapshot = await db
        .collection("Usuarios")
        .where("no", "==", no)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        res.status(409).send(`El usuario con nómina ${no} ya existe.`);
        return;
      }

      await db.collection("Usuarios").add({
        Título: Título ?? "",
        antiguedad: antiguedad ?? "",
        apellidos: apellidos ?? "",
        email: email ?? "",
        fechaIngreso: fechaIng ?? "",
        jefe: jefe ?? "",
        no: no ?? "",
        nombre,
        ns: ns ?? "",
        privilegio: privilegio ?? "",
        puesto: puesto ?? "",
        reporta: reporta ?? "",
        tipo: tipo ?? "",
        vacaciones: vacaciones ?? "",
        creadoDesde: "SharePoint",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(201).send(`Usuario ${nombre} creado correctamente.`);
    } catch (error: unknown) {
      console.error("Error al registrar usuario:", error);
      res.status(500).send("Error interno del servidor.");
    }
  }
);


export const actualizarUsuarioDesdeSharePoint = functions.https.onRequest(
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Método no permitido. Usa POST.");
        return;
      }

      const {
        Título,
        antiguedad,
        apellidos,
        email,
        fechaIng,
        fechaNac,
        jefe,
        nombre,
        ns,
        privilegio,
        puesto,
        reporta,
        tipo,
        vacaciones,
        no,
      } = req.body;

      if (!no) {
        res.status(400).send("Falta el campo 'no' ");
        return;
      }

      const snapshot = await db
        .collection("Usuarios")
        .where("no", "==", no)
        .limit(1)
        .get();

      if (snapshot.empty) {
        res.status(404).send(`No se encontró ningún usuario: ${no}.`);
        return;
      }

      const docId = snapshot.docs[0].id;

      await db.collection("Usuarios").doc(docId).update({
        Título: Título ?? "",
        antiguedad: antiguedad ?? "",
        apellidos: apellidos ?? "",
        email: email ?? "",
        fechaIng: fechaIng ?? "",
        fechaNac: fechaNac ?? "",
        jefe: jefe ?? "",
        nombre: nombre ?? "",
        ns: ns ?? "",
        privilegio: privilegio ?? "",
        puesto: puesto ?? "",
        reporta: reporta ?? "",
        tipo: tipo ?? "",
        vacaciones: vacaciones ?? "",
        no: no ?? "",
        actualizadoDesde: "SharePoint",
        actualizadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(`Usuario ${nombre ?? Título} actualizado`);
    } catch (error: unknown) {
      console.error("Error al actualizar usuario:", error);
      res.status(500).send("Error interno del servidor.");
    }
  }
);
export const eliminarUsuarioDesdeSharePoint = functions.https.onRequest(
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        res.status(405).send("Método no permitido. Usa POST.");
        return;
      }

      const {no} = req.body;

      if (!no) {
        res.status(400).send("Falta el campo 'no'.");
        return;
      }

      // Buscar documento por campo 'no'
      const snapshot = await db
        .collection("Usuarios")
        .where("no", "==", no)
        .limit(1)
        .get();

      if (snapshot.empty) {
        res.status(404).send(`No se encontró ningún usuario con nómina ${no}.`);
        return;
      }

      const docId = snapshot.docs[0].id;

      await db.collection("Usuarios").doc(docId).delete();

      res.status(200).send(`Usuario con nómina ${no} eliminado correctamente.`);
    } catch (error: unknown) {
      console.error("Error al eliminar usuario:", error);
      res.status(500).send("Error interno del servidor.");
    }
  }
);
