// Prisma 7 config: tells the Prisma CLI where the schema and database are.
// Put DATABASE_URL in a .env file (never commit it), e.g.
//   DATABASE_URL="postgresql://postgres:postgres@localhost:5432/pulseposter"
import "dotenv/config";
import { defineConfig, env } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { path: "prisma/migrations" },
  datasource: { url: env("DATABASE_URL") },
});