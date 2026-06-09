# Image Generation Prompts - Oracle to Azure PostgreSQL

## Thumbnail Prompt

**Use the following prompt across all image generators to create a thumbnail for this lab:**

### Prompt (for all generators):

> A professional tech illustration showing database migration from Oracle to PostgreSQL - on the left, Oracle database represented as a red/gold monolithic structure; on the right, Azure PostgreSQL as an open-source friendly blue elephant in the cloud. Include schema conversion arrows and code transformation visuals (PL/SQL to PL/pgSQL). Red-to-blue gradient color palette. 16:9 aspect ratio, clean modern design suitable as a repository thumbnail.

### Settings:
- **Aspect Ratio:** 16:9 (landscape)
- **Resolution:** 1792x1024 or similar
- **Style:** Professional tech illustration, clean, modern

### Generators to use:
1. **Google Gemini Pro** (Imagen 3)
2. **Azure OpenAI GPT-Image-2** (via Azure AI Foundry)
3. **Microsoft Image Creator** (Bing/Designer)

### Output:
Save generated images to:
- `assets/thumbnail-gemini.png`
- `assets/thumbnail-gpt-image.png`
- `assets/thumbnail-msdesigner.png`

After selecting the best one, rename to `assets/thumbnail.png` and update the `thumbnail` field in `appmodlab.md`.
