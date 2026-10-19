-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "vector";

-- CreateEnum
CREATE TYPE "SourceKind" AS ENUM ('SYNTHETIC', 'SELF_DESIGNED', 'ORGANISER_PERMISSION', 'CREATIVE_COMMONS', 'OWN_PHOTO', 'USER_UPLOAD');

-- CreateEnum
CREATE TYPE "AssetType" AS ENUM ('FLYER_IMAGE', 'FLYER_PHOTO', 'SOCIAL_SCREENSHOT', 'CHAT_SCREENSHOT', 'TEXT_CAPTION', 'TEXT_MESSAGE');

-- CreateEnum
CREATE TYPE "Split" AS ENUM ('UNASSIGNED', 'TRAIN', 'ADAPT', 'DEV', 'TEST');

-- CreateEnum
CREATE TYPE "ModelKind" AS ENUM ('IMAGE_EXTRACTOR', 'TEXT_EXTRACTOR', 'BASELINE_OCR_REGEX', 'BASELINE_OCR_BERT', 'DEDUP_MATCHER', 'RETRIEVER', 'PLANNER');

-- CreateEnum
CREATE TYPE "RunStatus" AS ENUM ('QUEUED', 'RUNNING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "LinkSource" AS ENUM ('MODEL', 'HUMAN');

-- CreateEnum
CREATE TYPE "PairDecision" AS ENUM ('PENDING', 'SAME', 'DIFFERENT');

-- CreateEnum
CREATE TYPE "EventStatus" AS ENUM ('SCHEDULED', 'CANCELLED', 'POSTPONED', 'SOLD_OUT', 'RELOCATED');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Source" (
    "id" TEXT NOT NULL,
    "kind" "SourceKind" NOT NULL,
    "description" TEXT NOT NULL,
    "licence" TEXT NOT NULL,
    "trainingAllowed" BOOLEAN NOT NULL,
    "redistributable" BOOLEAN NOT NULL,
    "permissionRef" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Source_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Asset" (
    "id" TEXT NOT NULL,
    "sourceId" TEXT NOT NULL,
    "uploadedById" TEXT,
    "type" "AssetType" NOT NULL,
    "storageKey" TEXT,
    "width" INTEGER,
    "height" INTEGER,
    "sha256" TEXT,
    "perceptualHash" TEXT,
    "text" TEXT,
    "referenceDatetime" TIMESTAMPTZ,
    "referenceTimezone" TEXT,
    "split" "Split" NOT NULL DEFAULT 'UNASSIGNED',
    "templateFamilyId" TEXT,
    "canonicalEventKey" TEXT,
    "isSynthetic" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Asset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Annotation" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "annotatorId" TEXT NOT NULL,
    "schemaVersion" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "isGold" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Annotation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ModelVersion" (
    "id" TEXT NOT NULL,
    "kind" "ModelKind" NOT NULL,
    "name" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "artifactUri" TEXT NOT NULL,
    "config" JSONB,
    "metrics" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ModelVersion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExtractionRun" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "modelVersionId" TEXT NOT NULL,
    "jobId" TEXT,
    "status" "RunStatus" NOT NULL DEFAULT 'QUEUED',
    "rawOutput" TEXT,
    "output" JSONB,
    "isValid" BOOLEAN,
    "error" TEXT,
    "latencyMs" INTEGER,
    "startedAt" TIMESTAMP(3),
    "finishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ExtractionRun_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FieldPrediction" (
    "id" TEXT NOT NULL,
    "runId" TEXT NOT NULL,
    "eventIndex" INTEGER NOT NULL,
    "field" TEXT NOT NULL,
    "value" JSONB,
    "confidence" DOUBLE PRECISION,
    "abstained" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "FieldPrediction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Correction" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "fieldPredictionId" TEXT,
    "userId" TEXT NOT NULL,
    "eventIndex" INTEGER NOT NULL,
    "field" TEXT NOT NULL,
    "oldValue" JSONB,
    "newValue" JSONB,
    "usedInDataset" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Correction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CanonicalEvent" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "startAt" TIMESTAMPTZ,
    "endAt" TIMESTAMPTZ,
    "venueName" TEXT,
    "address" TEXT,
    "organiser" TEXT,
    "priceMin" DECIMAL(10,2),
    "priceMax" DECIMAL(10,2),
    "currency" CHAR(3),
    "ticketUrl" TEXT,
    "categories" TEXT[],
    "status" "EventStatus" NOT NULL DEFAULT 'SCHEDULED',
    "details" JSONB NOT NULL,
    "embedding" vector(384),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CanonicalEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventMention" (
    "id" TEXT NOT NULL,
    "assetId" TEXT NOT NULL,
    "runId" TEXT,
    "eventIndex" INTEGER NOT NULL,
    "canonicalEventId" TEXT,
    "linkedBy" "LinkSource",
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EventMention_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DuplicatePair" (
    "id" TEXT NOT NULL,
    "mentionAId" TEXT NOT NULL,
    "mentionBId" TEXT NOT NULL,
    "modelVersionId" TEXT,
    "score" DOUBLE PRECISION,
    "decision" "PairDecision" NOT NULL DEFAULT 'PENDING',
    "decidedBy" "LinkSource",
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DuplicatePair_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Asset_sha256_key" ON "Asset"("sha256");

-- CreateIndex
CREATE INDEX "Asset_split_idx" ON "Asset"("split");

-- CreateIndex
CREATE INDEX "Asset_templateFamilyId_idx" ON "Asset"("templateFamilyId");

-- CreateIndex
CREATE INDEX "Asset_perceptualHash_idx" ON "Asset"("perceptualHash");

-- CreateIndex
CREATE INDEX "Annotation_assetId_idx" ON "Annotation"("assetId");

-- CreateIndex
CREATE UNIQUE INDEX "ModelVersion_name_version_key" ON "ModelVersion"("name", "version");

-- CreateIndex
CREATE INDEX "ExtractionRun_assetId_idx" ON "ExtractionRun"("assetId");

-- CreateIndex
CREATE INDEX "ExtractionRun_status_idx" ON "ExtractionRun"("status");

-- CreateIndex
CREATE INDEX "FieldPrediction_confidence_idx" ON "FieldPrediction"("confidence");

-- CreateIndex
CREATE UNIQUE INDEX "FieldPrediction_runId_eventIndex_field_key" ON "FieldPrediction"("runId", "eventIndex", "field");

-- CreateIndex
CREATE INDEX "Correction_assetId_idx" ON "Correction"("assetId");

-- CreateIndex
CREATE INDEX "CanonicalEvent_startAt_idx" ON "CanonicalEvent"("startAt");

-- CreateIndex
CREATE INDEX "EventMention_canonicalEventId_idx" ON "EventMention"("canonicalEventId");

-- CreateIndex
CREATE UNIQUE INDEX "EventMention_assetId_eventIndex_runId_key" ON "EventMention"("assetId", "eventIndex", "runId");

-- CreateIndex
CREATE INDEX "DuplicatePair_decision_idx" ON "DuplicatePair"("decision");

-- CreateIndex
CREATE UNIQUE INDEX "DuplicatePair_mentionAId_mentionBId_key" ON "DuplicatePair"("mentionAId", "mentionBId");

-- AddForeignKey
ALTER TABLE "Asset" ADD CONSTRAINT "Asset_sourceId_fkey" FOREIGN KEY ("sourceId") REFERENCES "Source"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Asset" ADD CONSTRAINT "Asset_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Annotation" ADD CONSTRAINT "Annotation_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Asset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Annotation" ADD CONSTRAINT "Annotation_annotatorId_fkey" FOREIGN KEY ("annotatorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExtractionRun" ADD CONSTRAINT "ExtractionRun_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Asset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExtractionRun" ADD CONSTRAINT "ExtractionRun_modelVersionId_fkey" FOREIGN KEY ("modelVersionId") REFERENCES "ModelVersion"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FieldPrediction" ADD CONSTRAINT "FieldPrediction_runId_fkey" FOREIGN KEY ("runId") REFERENCES "ExtractionRun"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Correction" ADD CONSTRAINT "Correction_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Asset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Correction" ADD CONSTRAINT "Correction_fieldPredictionId_fkey" FOREIGN KEY ("fieldPredictionId") REFERENCES "FieldPrediction"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Correction" ADD CONSTRAINT "Correction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventMention" ADD CONSTRAINT "EventMention_assetId_fkey" FOREIGN KEY ("assetId") REFERENCES "Asset"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventMention" ADD CONSTRAINT "EventMention_runId_fkey" FOREIGN KEY ("runId") REFERENCES "ExtractionRun"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventMention" ADD CONSTRAINT "EventMention_canonicalEventId_fkey" FOREIGN KEY ("canonicalEventId") REFERENCES "CanonicalEvent"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DuplicatePair" ADD CONSTRAINT "DuplicatePair_mentionAId_fkey" FOREIGN KEY ("mentionAId") REFERENCES "EventMention"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DuplicatePair" ADD CONSTRAINT "DuplicatePair_mentionBId_fkey" FOREIGN KEY ("mentionBId") REFERENCES "EventMention"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DuplicatePair" ADD CONSTRAINT "DuplicatePair_modelVersionId_fkey" FOREIGN KEY ("modelVersionId") REFERENCES "ModelVersion"("id") ON DELETE SET NULL ON UPDATE CASCADE;
