// Vendure's own environment.d.ts (@vendure/create), for MariaDB, plus the variables Waddle's .env
// adds like SITE_URL and the mail settings.
export {};

// Here we declare the members of the process.env object, so that we
// can use them in our application code in a type-safe manner.
declare global {
    namespace NodeJS {
        interface ProcessEnv {
            APP_ENV: string;
            VENDURE_SERVER_PORT: string;
            PORT: string;
            COOKIE_SECRET: string;
            SUPERADMIN_USERNAME: string;
            SUPERADMIN_PASSWORD: string;
            CORS_ORIGINS?: string;
            DB_HOST: string;
            DB_PORT: number;
            DB_NAME: string;
            DB_USERNAME: string;
            DB_PASSWORD: string;
            SITE_URL: string;
            SMTP_HOST?: string;
            SMTP_PORT?: string;
            MAIL_FROM: string;
        }
    }
}
