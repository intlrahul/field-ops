// Request/response schemas for the public assets and inspections contract.
export const httpSchemas: Record<string, object> = {
  "InspectionStatistics": {
    "$id": "domain.InspectionStatistics",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "total",
      "assigned",
      "inProgress",
      "completed"
    ],
    "properties": {
      "total": {
        "type": "integer",
        "minimum": 0
      },
      "assigned": {
        "type": "integer",
        "minimum": 0
      },
      "inProgress": {
        "type": "integer",
        "minimum": 0
      },
      "completed": {
        "type": "integer",
        "minimum": 0
      }
    }
  },
  "AssetCreate": {
    "$id": "domain.AssetCreate",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "assetTag",
      "name"
    ],
    "properties": {
      "assetTag": {
        "type": "string",
        "minLength": 1,
        "maxLength": 40,
        "pattern": "^[A-Z0-9-]+$"
      },
      "name": {
        "type": "string",
        "minLength": 1,
        "maxLength": 120,
        "pattern": "\\S"
      },
      "location": {
        "type": "string",
        "minLength": 1,
        "maxLength": 200,
        "pattern": "\\S",
        "nullable": true
      }
    }
  },
  "AssetSnapshot": {
    "$id": "domain.AssetSnapshot",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "assetTag",
      "name",
      "location"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "assetTag": {
        "type": "string",
        "minLength": 1,
        "maxLength": 40,
        "pattern": "^[A-Z0-9-]+$"
      },
      "name": {
        "type": "string",
        "minLength": 1,
        "maxLength": 120,
        "pattern": "\\S"
      },
      "location": {
        "type": "string",
        "minLength": 1,
        "maxLength": 200,
        "pattern": "\\S",
        "nullable": true
      }
    }
  },
  "Asset": {
    "$id": "domain.Asset",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "assetTag",
      "name",
      "location",
      "createdAt",
      "updatedAt",
      "version",
      "organizationId"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "assetTag": {
        "type": "string",
        "minLength": 1,
        "maxLength": 40,
        "pattern": "^[A-Z0-9-]+$"
      },
      "name": {
        "type": "string",
        "minLength": 1,
        "maxLength": 120,
        "pattern": "\\S"
      },
      "location": {
        "type": "string",
        "minLength": 1,
        "maxLength": 200,
        "pattern": "\\S",
        "nullable": true
      },
      "createdAt": {
        "type": "string",
        "format": "date-time"
      },
      "updatedAt": {
        "type": "string",
        "format": "date-time"
      },
      "version": {
        "type": "integer",
        "minimum": 1
      },
      "organizationId": {
        "type": "string",
        "format": "uuid",
        "description": "Server-owned organization identifier."
      }
    }
  },
  "ChecklistDefinition": {
    "$id": "domain.ChecklistDefinition",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "label",
      "required"
    ],
    "properties": {
      "label": {
        "type": "string",
        "minLength": 1,
        "maxLength": 160,
        "pattern": "\\S"
      },
      "required": {
        "type": "boolean"
      }
    }
  },
  "ReadingDefinition": {
    "$id": "domain.ReadingDefinition",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "label",
      "unit",
      "required",
      "minValue",
      "maxValue"
    ],
    "properties": {
      "label": {
        "type": "string",
        "minLength": 1,
        "maxLength": 120,
        "pattern": "\\S"
      },
      "unit": {
        "type": "string",
        "minLength": 1,
        "maxLength": 24,
        "pattern": "\\S"
      },
      "required": {
        "type": "boolean"
      },
      "minValue": {
        "type": "number",
        "nullable": true
      },
      "maxValue": {
        "type": "number",
        "nullable": true
      }
    }
  },
  "InspectionCreate": {
    "$id": "domain.InspectionCreate",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "assetId",
      "assigneeId",
      "title",
      "checklistItems",
      "readingDefinitions"
    ],
    "properties": {
      "assetId": {
        "type": "string",
        "format": "uuid"
      },
      "assigneeId": {
        "type": "string",
        "format": "uuid"
      },
      "title": {
        "type": "string",
        "minLength": 1,
        "maxLength": 160,
        "pattern": "\\S"
      },
      "dueAt": {
        "type": "string",
        "format": "date-time",
        "nullable": true
      },
      "checklistItems": {
        "type": "array",
        "items": {
          "$ref": "domain.ChecklistDefinition#"
        },
        "minItems": 1,
        "maxItems": 30
      },
      "readingDefinitions": {
        "type": "array",
        "items": {
          "$ref": "domain.ReadingDefinition#"
        },
        "maxItems": 10
      }
    }
  },
  "InspectionSummary": {
    "$id": "domain.InspectionSummary",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "title",
      "status",
      "asset",
      "assigneeId",
      "dueAt",
      "createdAt",
      "updatedAt",
      "version",
      "organizationId"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "title": {
        "type": "string",
        "minLength": 1,
        "maxLength": 160,
        "pattern": "\\S"
      },
      "status": {
        "type": "string",
        "enum": [
          "assigned",
          "in_progress",
          "completed"
        ]
      },
      "asset": {
        "$ref": "domain.AssetSnapshot#"
      },
      "assigneeId": {
        "type": "string",
        "format": "uuid"
      },
      "dueAt": {
        "type": "string",
        "format": "date-time",
        "nullable": true
      },
      "createdAt": {
        "type": "string",
        "format": "date-time"
      },
      "updatedAt": {
        "type": "string",
        "format": "date-time"
      },
      "version": {
        "type": "integer",
        "minimum": 1
      },
      "organizationId": {
        "type": "string",
        "format": "uuid",
        "description": "Server-owned organization identifier."
      }
    }
  },
  "ChecklistItem": {
    "$id": "domain.ChecklistItem",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "position",
      "label",
      "required",
      "result",
      "failureNote"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "position": {
        "type": "integer",
        "minimum": 0
      },
      "label": {
        "type": "string",
        "minLength": 1,
        "maxLength": 160,
        "pattern": "\\S"
      },
      "required": {
        "type": "boolean"
      },
      "result": {
        "type": "string",
        "enum": [
          "pass",
          "fail",
          null
        ],
        "nullable": true
      },
      "failureNote": {
        "type": "string",
        "nullable": true,
        "maxLength": 2000
      }
    }
  },
  "Reading": {
    "$id": "domain.Reading",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "position",
      "label",
      "unit",
      "required",
      "minValue",
      "maxValue",
      "value",
      "rangeStatus"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "position": {
        "type": "integer",
        "minimum": 0
      },
      "label": {
        "type": "string",
        "minLength": 1,
        "maxLength": 120,
        "pattern": "\\S"
      },
      "unit": {
        "type": "string",
        "minLength": 1,
        "maxLength": 24,
        "pattern": "\\S"
      },
      "required": {
        "type": "boolean"
      },
      "minValue": {
        "type": "number",
        "nullable": true
      },
      "maxValue": {
        "type": "number",
        "nullable": true
      },
      "value": {
        "type": "number",
        "nullable": true
      },
      "rangeStatus": {
        "type": "string",
        "enum": [
          "unrecorded",
          "in_range",
          "out_of_range"
        ]
      }
    }
  },
  "Note": {
    "$id": "domain.Note",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "authorId",
      "text",
      "createdAt"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "authorId": {
        "type": "string",
        "format": "uuid"
      },
      "text": {
        "type": "string",
        "minLength": 1,
        "maxLength": 2000,
        "pattern": "\\S"
      },
      "createdAt": {
        "type": "string",
        "format": "date-time"
      }
    }
  },
  "InspectionDetail": {
    "$id": "domain.InspectionDetail",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "id",
      "title",
      "status",
      "asset",
      "assigneeId",
      "dueAt",
      "createdAt",
      "updatedAt",
      "version",
      "checklistItems",
      "readings",
      "notes",
      "startedAt",
      "completedAt",
      "organizationId",
      "allowedActions",
      "completionBlockers"
    ],
    "properties": {
      "id": {
        "type": "string",
        "format": "uuid"
      },
      "title": {
        "type": "string",
        "minLength": 1,
        "maxLength": 160,
        "pattern": "\\S"
      },
      "status": {
        "type": "string",
        "enum": [
          "assigned",
          "in_progress",
          "completed"
        ]
      },
      "asset": {
        "$ref": "domain.AssetSnapshot#"
      },
      "assigneeId": {
        "type": "string",
        "format": "uuid"
      },
      "dueAt": {
        "type": "string",
        "format": "date-time",
        "nullable": true
      },
      "createdAt": {
        "type": "string",
        "format": "date-time"
      },
      "updatedAt": {
        "type": "string",
        "format": "date-time"
      },
      "version": {
        "type": "integer",
        "minimum": 1
      },
      "checklistItems": {
        "type": "array",
        "items": {
          "$ref": "domain.ChecklistItem#"
        }
      },
      "readings": {
        "type": "array",
        "items": {
          "$ref": "domain.Reading#"
        }
      },
      "notes": {
        "type": "array",
        "items": {
          "$ref": "domain.Note#"
        }
      },
      "startedAt": {
        "type": "string",
        "format": "date-time",
        "nullable": true
      },
      "completedAt": {
        "type": "string",
        "format": "date-time",
        "nullable": true
      },
      "organizationId": {
        "type": "string",
        "format": "uuid",
        "description": "Server-owned organization identifier."
      },
      "allowedActions": {
        "type": "array",
        "uniqueItems": true,
        "items": {
          "type": "string"
        },
        "description": "Actor-specific available actions: start, edit_answers, edit_readings, add_note, complete. Missing or unknown entries grant nothing; reauthorized on every request."
      },
      "completionBlockers": {
        "type": "array",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "code",
            "itemId"
          ],
          "properties": {
            "code": {
              "type": "string"
            },
            "itemId": {
              "type": "string",
              "format": "uuid"
            }
          }
        }
      }
    }
  },
  "AssetPage": {
    "$id": "domain.AssetPage",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "items",
      "nextCursor"
    ],
    "properties": {
      "items": {
        "type": "array",
        "items": {
          "$ref": "domain.Asset#"
        }
      },
      "nextCursor": {
        "type": "string",
        "nullable": true
      }
    }
  },
  "InspectionSummaryPage": {
    "$id": "domain.InspectionSummaryPage",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "items",
      "nextCursor"
    ],
    "properties": {
      "items": {
        "type": "array",
        "items": {
          "$ref": "domain.InspectionSummary#"
        }
      },
      "nextCursor": {
        "type": "string",
        "nullable": true
      }
    }
  },
  "ChecklistResultInput": {
    "$id": "domain.ChecklistResultInput",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "result"
    ],
    "properties": {
      "result": {
        "type": "string",
        "enum": [
          "pass",
          "fail",
          null
        ],
        "nullable": true
      },
      "failureNote": {
        "type": "string",
        "nullable": true,
        "maxLength": 2000
      }
    }
  },
  "ReadingValueInput": {
    "$id": "domain.ReadingValueInput",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "value"
    ],
    "properties": {
      "value": {
        "type": "number"
      }
    }
  },
  "NoteInput": {
    "$id": "domain.NoteInput",
    "type": "object",
    "additionalProperties": false,
    "required": [
      "text"
    ],
    "properties": {
      "text": {
        "type": "string",
        "minLength": 1,
        "maxLength": 2000,
        "pattern": "\\S"
      }
    }
  }
};
