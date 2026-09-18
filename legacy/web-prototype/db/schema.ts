import { sqliteTable,text,integer } from "drizzle-orm/sqlite-core";
export const diaries=sqliteTable("diaries",{
 session:text("session").primaryKey(),
 state:text("state").notNull(),
 updatedAt:integer("updated_at").notNull()
});
