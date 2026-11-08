import {
  S3Client,
  CreateBucketCommand,
  HeadBucketCommand,
} from "@aws-sdk/client-s3";
const client = new S3Client({
  endpoint: "http://object-storage:9000",
  region: "us-east-1",
  forcePathStyle: true,
  credentials: {
    accessKeyId: process.env.MEDIA_ACCESS_KEY_ID,
    secretAccessKey: process.env.MEDIA_SECRET_ACCESS_KEY,
  },
  requestChecksumCalculation: "WHEN_REQUIRED",
});
try {
  try {
    await client.send(new HeadBucketCommand({ Bucket: "vecinal-fotos" }));
  } catch (error) {
    if (error.$metadata?.httpStatusCode !== 404) throw error;
    await client.send(new CreateBucketCommand({ Bucket: "vecinal-fotos" }));
  }
  // No public-read ACL, website or anonymous policy is ever installed.
  console.log("Bucket privado de desarrollo preparado.");
} catch {
  console.error("No se pudo preparar el almacenamiento local.");
  process.exitCode = 1;
} finally {
  client.destroy();
}
