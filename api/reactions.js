// api/comments.js
import { MongoClient } from 'mongodb';

const uri = process.env.MONGODB_URI;
let cachedDb = null;

async function connectToDatabase() {
    if (cachedDb) {
        return cachedDb;
    }
    if (!uri) {
        throw new Error('MONGODB_URI is not defined in environment variables.');
    }
    const client = await MongoClient.connect(uri);
    const db = client.db('myResumeDb'); 
    cachedDb = db;
    return db;
}

export default async function handler(request, response) {
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method === 'OPTIONS') {
        return response.status(200).end();
    }

    let db;
    try {
        db = await connectToDatabase();
    } catch (error) {
        console.error("Failed to connect to database:", error);
        return response.status(500).json({ message: 'Failed to connect to database', error: error.message });
    }

    if (request.method === 'POST') {
        try {
            const commentsCollection = db.collection('comments');
            const { portfolioItemId, author, commentText } = request.body;

            if (!portfolioItemId || !author || !commentText) {
                return response.status(400).json({ message: 'Missing required fields: portfolioItemId, author, or commentText' });
            }

            const result = await commentsCollection.insertOne({
                portfolioItemId,
                author,
                commentText,
                timestamp: new Date(),
            });

            response.status(201).json({ message: 'Comment added successfully', commentId: result.insertedId });

        } catch (error) {
            console.error('Error adding comment:', error);
            response.status(500).json({ message: 'Failed to add comment', error: error.message });
        }
    } else if (request.method === 'GET') {
        try {
            const commentsCollection = db.collection('comments');
            const { portfolioItemId } = request.query;

            if (!portfolioItemId) {
                return response.status(400).json({ message: 'Missing portfolioItemId query parameter.' });
            }

            const comments = await commentsCollection.find({ portfolioItemId })
                                                    .sort({ timestamp: -1 })
                                                    .toArray();

            response.status(200).json(comments);

        } catch (error) {
            console.error('Error fetching comments:', error);
            response.status(500).json({ message: 'Failed to fetch comments', error: error.message });
        }
    } else {
        response.setHeader('Allow', ['POST', 'GET', 'OPTIONS']);
        response.status(405).end(`Method ${request.method} Not Allowed`);
    }
}
