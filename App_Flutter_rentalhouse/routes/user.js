// Get user's notifications (Thông báo)
router.get('/notifications', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (Number(page) - 1) * Number(limit);

    const userRentals = await Rental.find({ userId: req.userId }).select('_id').lean();
    const rentalIds = userRentals.map((rental) => rental._id);

    const [comments, total] = await Promise.all([
      Comment.find({ 
        rentalId: { $in: rentalIds },
        userId: { $ne: req.userId } // Exclude comments from current user
      })
        .populate('userId', 'username')
        .populate('rentalId', 'title')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit))
        .lean(),
      Comment.countDocuments({ 
        rentalId: { $in: rentalIds },
        userId: { $ne: req.userId } // Exclude comments from current user
      }),
    ]);

    const notifications = comments.map((comment) => ({
      type: 'Comment',
      message: `${comment.userId?.username || 'Unknown'} đã bình luận về bài viết của bạn : "${comment.rentalId?.title || 'Unknown'}"`,
      content: comment.content,
      createdAt: new Date(comment.createdAt.getTime() + 7 * 60 * 60 * 1000),
      rentalId: comment.rentalId?._id,
      commentId: comment._id,
    }));

    res.json({
      notifications,
      total,
      page: Number(page),
      pages: Math.ceil(total / Number(limit)),
    });
  } catch (err) {
    console.error('Fetch notifications error:', err.stack);
    res.status(500).json({ message: 'Failed to fetch notifications', error: err.message });
  }
}); 