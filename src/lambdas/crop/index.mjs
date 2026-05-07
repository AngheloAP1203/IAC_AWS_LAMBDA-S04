// Funcionalidad: Lógica de recorte de imagen a 40x40 (Jimp/Sharp)
import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import Jimp from 'jimp';

const s3 = new S3Client({});

export const handler = async (event) => {
    for (const record of event.Records) {
        const s3Event = JSON.parse(record.body).Records[0].s3;
        const bucket = s3Event.bucket.name;
        const key = decodeURIComponent(s3Event.object.key.replace(/\+/g, ' '));

        try {
            const response = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
            const chunks = [];
            for await (const chunk of response.Body) chunks.push(chunk);
            const buffer = Buffer.concat(chunks);

            const image = await Jimp.read(buffer);

            image.cover(40, 40)
                .circle();

            const processed = await image.getBufferAsync(Jimp.MIME_PNG);

            const newKey = key.replace('uploads/', 'processed/').replace(/\.[^.]+$/, '.png');

            await s3.send(new PutObjectCommand({
                Bucket: bucket,
                Key: newKey,
                Body: processed,
                ContentType: 'image/png'
            }));

            console.log(`Procesado exitoso con Jimp: ${newKey}`);
        } catch (error) {
            console.error(`Error procesando ${key}:`, error);
            throw error;
        }
    }
};