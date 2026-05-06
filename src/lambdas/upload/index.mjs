import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { v4 as uuidv4 } from 'uuid';
import busboy from 'busboy';

const s3 = new S3Client({});

function parseMultipart(event) {
    return new Promise((resolve, reject) => {
        const bb = busboy({ headers: event.headers });
        let fileBuffer = null;
        let mimeType = 'image/png';

        bb.on('file', (_field, file, info) => {
            mimeType = info.mimeType || 'image/png';
            const chunks = [];
            file.on('data', (chunk) => chunks.push(chunk));
            file.on('end', () => { fileBuffer = Buffer.concat(chunks); });
        });

        bb.on('finish', () => resolve({ fileBuffer, mimeType }));
        bb.on('error', reject);

        const body = event.isBase64Encoded
            ? Buffer.from(event.body, 'base64')
            : Buffer.from(event.body, 'utf8');

        bb.write(body);
        bb.end();
    });
}

export const handler = async (event) => {
    console.log("Evento recibido:", JSON.stringify(event));
    try {
        const bucket = process.env.S3_BUCKET;
        const prefix = process.env.UPLOAD_PREFIX;
        const contentType = event.headers['content-type'] || event.headers['Content-Type'] || '';
        const fileName = `${uuidv4()}.png`;

        let fileBuffer;
        let fileMimeType;

        if (contentType.startsWith('multipart/form-data')) {
            const parsed = await parseMultipart(event);
            fileBuffer = parsed.fileBuffer;
            fileMimeType = parsed.mimeType;
        } else {
            fileBuffer = event.isBase64Encoded
                ? Buffer.from(event.body, 'base64')
                : Buffer.from(event.body);
            fileMimeType = contentType || 'image/png';
        }

        if (!fileBuffer || fileBuffer.length === 0) {
            throw new Error("El cuerpo de la imagen está vacío");
        }

        await s3.send(new PutObjectCommand({
            Bucket: bucket,
            Key: `${prefix}${fileName}`,
            Body: fileBuffer,
            ContentType: fileMimeType
        }));

        return {
            statusCode: 201,
            body: JSON.stringify({ message: "Imagen recibida", file: fileName })
        };
    } catch (err) {
        console.error("ERROR CRITICO:", err.message);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: err.message, stack: err.stack })
        };
    }
};
