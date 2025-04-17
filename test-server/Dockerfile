FROM node:22

EXPOSE 11445

WORKDIR /test-server

COPY --chown=node:node . .

RUN npm install
RUN npm run build

USER node
CMD ["node", "dist/index.js"]
