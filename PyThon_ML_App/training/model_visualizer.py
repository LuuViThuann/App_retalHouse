import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import joblib

# Thêm thư mục cha vào path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class ModelVisualizer:
    def __init__(self, model_path='./models/recommendation_model.pkl'):
        """Load model và chuẩn bị visualization"""
        print("\n" + "="*70)
        print("📊 MODEL VISUALIZER - PHÂN TÍCH MÔ HÌNH AI")
        print("="*70 + "\n")
        
        # Load model
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")
        
        print(f"📂 Loading model from {model_path}...")
        model_data = joblib.load(model_path)
        
        self.user_item_matrix = model_data['user_item_matrix']
        self.user_similarity = model_data['user_similarity']
        self.item_similarity = model_data['item_similarity']
        self.user_encoder = model_data['user_encoder']
        self.item_encoder = model_data['item_encoder']
        self.popularity_scores = model_data['popularity_scores']
        self.rental_coordinates = model_data.get('rental_coordinates', {})
        self.user_locations = model_data.get('user_locations', {})
        
        print(f"✅ Model loaded successfully\n")
        
        # Tạo thư mục output
        self.output_dir = './reports'
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Cấu hình matplotlib
        plt.style.use('seaborn-v0_8-darkgrid')
        sns.set_palette("husl")
    
    def calculate_correct_sparsity(self):
        """
        🔥 FIX: Tính đúng độ thưa của ma trận
        
        Công thức đúng:
        sparsity = (1 - nnz / total_cells) × 100%
        
        Ví dụ:
        - Ma trận 12 users × 15 items = 180 cells
        - Có 50 cells khác 0
        - sparsity = (1 - 50/180) × 100% = 72.22%
        """
        n_users = self.user_item_matrix.shape[0]
        n_items = self.user_item_matrix.shape[1]
        total_cells = n_users * n_items
        nnz = self.user_item_matrix.nnz  # Number of non-zero
        
        sparsity = (1 - nnz / total_cells) * 100
        
        return {
            'n_users': n_users,
            'n_items': n_items,
            'total_cells': total_cells,
            'nnz': nnz,
            'sparsity': sparsity,
            'density': 100 - sparsity
        }
    
    def plot_matrix_heatmap(self):
        """
        📊 BIỂU ĐỒ 1: Ma trận User-Item Heatmap
        
        Hiển thị:
        - Hàng: Users
        - Cột: Items (Rentals)
        - Màu: Điểm tương tác (0 = trắng, cao = đỏ)
        """
        print("📊 [1/7] Tạo biểu đồ Ma trận User-Item...")
        
        # Convert sparse matrix to dense (cẩn thận với ma trận lớn!)
        matrix_dense = self.user_item_matrix.toarray()
        
        fig, ax = plt.subplots(figsize=(14, 8))
        
        # Vẽ heatmap
        sns.heatmap(
            matrix_dense,
            cmap='YlOrRd',
            cbar_kws={'label': 'Điểm tương tác'},
            xticklabels=False,  # Ẩn label nếu quá nhiều
            yticklabels=False,
            ax=ax
        )
        
        # Tính stats
        stats = self.calculate_correct_sparsity()
        
        ax.set_title(
            f'Ma trận User-Item ({stats["n_users"]} users × {stats["n_items"]} items)\n'
            f'Độ thưa: {stats["sparsity"]:.2f}% | '
            f'Density: {stats["density"]:.2f}% | '
            f'Non-zero cells: {stats["nnz"]:,}',
            fontsize=14,
            pad=20
        )
        ax.set_xlabel(f'Items (Rentals) - {stats["n_items"]} bài', fontsize=12)
        ax.set_ylabel(f'Users - {stats["n_users"]} người', fontsize=12)
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '1_user_item_matrix.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
        
        return stats
    
    def plot_interaction_distribution(self):
        """
        📊 BIỂU ĐỒ 2: Phân bố điểm tương tác
        
        Hiển thị histogram của interaction scores
        """
        print("📊 [2/7] Tạo biểu đồ Phân bố điểm tương tác...")
        
        # Lấy tất cả giá trị non-zero
        scores = self.user_item_matrix.data
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
        
        # Histogram
        ax1.hist(scores, bins=20, edgecolor='black', alpha=0.7)
        ax1.set_title('Phân bố điểm tương tác', fontsize=14)
        ax1.set_xlabel('Điểm tương tác', fontsize=12)
        ax1.set_ylabel('Số lượng', fontsize=12)
        ax1.grid(alpha=0.3)
        
        # Box plot
        ax2.boxplot(scores, vert=True)
        ax2.set_title('Box Plot - Điểm tương tác', fontsize=14)
        ax2.set_ylabel('Điểm tương tác', fontsize=12)
        ax2.grid(alpha=0.3)
        
        # Stats
        mean_score = np.mean(scores)
        median_score = np.median(scores)
        ax1.axvline(mean_score, color='red', linestyle='--', 
                    label=f'Trung bình: {mean_score:.2f}')
        ax1.axvline(median_score, color='green', linestyle='--', 
                    label=f'Trung vị: {median_score:.2f}')
        ax1.legend()
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '2_interaction_distribution.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
    
    def plot_user_similarity_heatmap(self):
        """
        📊 BIỂU ĐỒ 3: Ma trận độ tương đồng User-User
        
        Hiển thị mức độ giống nhau giữa các users
        """
        print("📊 [3/7] Tạo biểu đồ Độ tương đồng User-User...")
        
        # Convert to dense (nếu là sparse)
        if hasattr(self.user_similarity, 'toarray'):
            sim_matrix = self.user_similarity.toarray()
        else:
            sim_matrix = self.user_similarity
        
        fig, ax = plt.subplots(figsize=(10, 8))
        
        sns.heatmap(
            sim_matrix,
            cmap='coolwarm',
            center=0,
            vmin=-1,
            vmax=1,
            square=True,
            cbar_kws={'label': 'Độ tương đồng (-1 đến 1)'},
            xticklabels=False,
            yticklabels=False,
            ax=ax
        )
        
        ax.set_title(
            f'Ma trận độ tương đồng User-User ({sim_matrix.shape[0]} users)',
            fontsize=14,
            pad=20
        )
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '3_user_similarity.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
    
    def plot_popularity_chart(self):
        """
        📊 BIỂU ĐỒ 4: Top 10 bài đăng phổ biến nhất
        """
        print("📊 [4/7] Tạo biểu đồ Top bài đăng phổ biến...")
        
        # Sort by popularity
        sorted_items = sorted(
            self.popularity_scores.items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]
        
        rental_ids = [item[0][:12] + '...' for item in sorted_items]
        scores = [item[1] for item in sorted_items]
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        bars = ax.barh(rental_ids, scores, color='skyblue', edgecolor='black')
        
        # Thêm giá trị trên thanh
        for i, (bar, score) in enumerate(zip(bars, scores)):
            ax.text(
                score + 1,
                i,
                f'{score:.1f}',
                va='center',
                fontsize=10
            )
        
        ax.set_xlabel('Điểm phổ biến', fontsize=12)
        ax.set_ylabel('Rental ID', fontsize=12)
        ax.set_title('Top 10 Bài đăng phổ biến nhất', fontsize=14)
        ax.grid(axis='x', alpha=0.3)
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '4_popularity_ranking.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
    
    def plot_geographic_distribution(self):
        """
        📊 BIỂU ĐỒ 5: Phân bố địa lý của rentals và users
        """
        print("📊 [5/7] Tạo biểu đồ Phân bố địa lý...")
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        
        # Rental coordinates
        if self.rental_coordinates:
            rental_lons = [coord[0] for coord in self.rental_coordinates.values() 
                          if coord[0] != 0]
            rental_lats = [coord[1] for coord in self.rental_coordinates.values() 
                          if coord[1] != 0]
            
            ax1.scatter(rental_lons, rental_lats, 
                       s=100, alpha=0.6, c='red', edgecolors='black')
            ax1.set_title(f'Vị trí Rentals ({len(rental_lons)} bài)', fontsize=14)
            ax1.set_xlabel('Longitude (Kinh độ)', fontsize=12)
            ax1.set_ylabel('Latitude (Vĩ độ)', fontsize=12)
            ax1.grid(alpha=0.3)
        
        # User locations
        if self.user_locations:
            user_lons = [coord[0] for coord in self.user_locations.values()]
            user_lats = [coord[1] for coord in self.user_locations.values()]
            
            ax2.scatter(user_lons, user_lats,
                       s=100, alpha=0.6, c='blue', edgecolors='black')
            ax2.set_title(f'Vị trí trung tâm Users ({len(user_lons)} người)', 
                         fontsize=14)
            ax2.set_xlabel('Longitude (Kinh độ)', fontsize=12)
            ax2.set_ylabel('Latitude (Vĩ độ)', fontsize=12)
            ax2.grid(alpha=0.3)
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '5_geographic_distribution.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
    
    def plot_interactions_per_user(self):
        """
        📊 BIỂU ĐỒ 6: Số lượng tương tác mỗi user
        """
        print("📊 [6/7] Tạo biểu đồ Tương tác mỗi user...")
        
        # Đếm interactions per user
        interactions_count = np.array(self.user_item_matrix.sum(axis=1)).flatten()
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
        
        # Bar chart
        users = [f'U{i+1}' for i in range(len(interactions_count))]
        ax1.bar(users, interactions_count, color='steelblue', edgecolor='black')
        ax1.set_title('Số lượng tương tác mỗi User', fontsize=14)
        ax1.set_xlabel('User', fontsize=12)
        ax1.set_ylabel('Tổng điểm tương tác', fontsize=12)
        ax1.tick_params(axis='x', rotation=45)
        ax1.grid(axis='y', alpha=0.3)
        
        # Histogram phân bố
        ax2.hist(interactions_count, bins=10, edgecolor='black', alpha=0.7)
        ax2.set_title('Phân bố số lượng tương tác', fontsize=14)
        ax2.set_xlabel('Tổng điểm tương tác', fontsize=12)
        ax2.set_ylabel('Số lượng users', fontsize=12)
        ax2.grid(alpha=0.3)
        
        # Stats
        mean_interactions = np.mean(interactions_count)
        ax2.axvline(mean_interactions, color='red', linestyle='--',
                   label=f'Trung bình: {mean_interactions:.1f}')
        ax2.legend()
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '6_interactions_per_user.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")
    
    def plot_interactions_per_item(self):
        """
        📊 BIỂU ĐỒ 7: Số lượng tương tác mỗi rental
        """
        print("📊 [7/7] Tạo biểu đồ Tương tác mỗi rental...")
        
        # Đếm interactions per item
        interactions_count = np.array(self.user_item_matrix.sum(axis=0)).flatten()
        
        # Sort để dễ nhìn
        sorted_indices = np.argsort(interactions_count)[::-1]
        sorted_counts = interactions_count[sorted_indices]
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        items = [f'R{i+1}' for i in range(len(sorted_counts))]
        bars = ax.bar(items, sorted_counts, color='coral', edgecolor='black')
        
        # Highlight top 3
        for i in range(min(3, len(bars))):
            bars[i].set_color('gold')
            bars[i].set_edgecolor('red')
            bars[i].set_linewidth(2)
        
        ax.set_title('Số lượng tương tác mỗi Rental (sắp xếp giảm dần)', 
                    fontsize=14)
        ax.set_xlabel('Rental', fontsize=12)
        ax.set_ylabel('Tổng điểm tương tác', fontsize=12)
        ax.grid(axis='y', alpha=0.3)
        
        plt.tight_layout()
        output_path = os.path.join(self.output_dir, '7_interactions_per_item.png')
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
        
        print(f"   ✅ Saved: {output_path}\n")