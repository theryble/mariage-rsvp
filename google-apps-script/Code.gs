/**
 * Réception des réponses du formulaire « Vin d'honneur — Marine & Jeremy ».
 * À coller dans l'éditeur Apps Script d'une feuille Google (voir README.md).
 */

const SHEET_NAME = 'Réponses';
const HEADERS = ['Identifiant', 'Prénom', 'Nom', 'Présence', 'Contact', 'Message', 'Reçue le', 'Modifiée le'];

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const d = JSON.parse(e.postData.contents);

    // Champ piège rempli : c'est un robot, on fait semblant d'accepter.
    if (d.website) return json({ ok: true });

    const id = String(d.id || '');
    const firstName = clean(d.firstName, 60);
    const lastName = clean(d.lastName, 60);
    if (!/^[A-Za-z0-9-]{8,64}$/.test(id)) return json({ ok: false, error: 'identifiant invalide' });
    if (!firstName || !lastName) return json({ ok: false, error: 'nom manquant' });
    if (d.attending !== 'yes' && d.attending !== 'no') return json({ ok: false, error: 'présence manquante' });

    const row = [
      id,
      firstName,
      lastName,
      d.attending === 'yes' ? 'Présent(e)' : 'Absent(e)',
      clean(d.contact, 120),
      clean(d.message, 600)
    ];

    const sheet = getSheet();
    const now = new Date();
    const last = sheet.getLastRow();
    const ids = last > 1 ? sheet.getRange(2, 1, last - 1, 1).getValues().map(r => r[0]) : [];
    const index = ids.indexOf(id);

    let r;
    if (index >= 0) {
      r = index + 2;
      sheet.getRange(r, 1, 1, row.length).setValues([row]);
      sheet.getRange(r, 8).setValue(now);
    } else {
      sheet.appendRow(row.concat([now, now]));
      r = sheet.getLastRow();
    }
    // « Reçue le » et « Modifiée le » affichées avec la date et l'heure.
    sheet.getRange(r, 7, 1, 2).setNumberFormat('dd/mm/yyyy hh:mm');
    return json({ ok: true });
  } catch (err) {
    return json({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

// Permet de vérifier que l'application Web répond en ouvrant son adresse.
function doGet() {
  return json({ ok: true, service: 'rsvp-marine-jeremy' });
}

function getSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) sheet = ss.insertSheet(SHEET_NAME);
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, HEADERS.length).setFontWeight('bold');
  }
  return sheet;
}

// Coupe la longueur et neutralise les formules (=, +, -, @) pour qu'une réponse
// ne puisse pas s'exécuter dans la feuille.
function clean(value, max) {
  let s = String(value == null ? '' : value).trim().slice(0, max);
  if (/^[=+\-@]/.test(s)) s = "'" + s;
  return s;
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
