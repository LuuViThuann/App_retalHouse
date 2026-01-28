import os
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import joblib
from matplotlib import rcParams

# Cấu hình font cho Vietnamese
rcParams['font.sans-serif'] = ['DejaVu Sans']
rcParams['axes.unicode_minus'] = False

class ModelVisualizer:
    def __init__(self, model_path='./models/recommendation_model.pkl'):
        """Load model và chuẩn bị visualization"""
        print("\n" + "="*70)
        print("📊 MODEL VISUALIZER - PHÂN TÍCH MÔ HÌNH AI (FIXED)")
        print("="*70 + "\n")
        
        # 🔥 FIX: Check file exists và readable
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")
        
        if not os.path.isfile(model_path):
            raise FileNotFoundError(f"Not a file: {model_path}")
        
        file_size = os.path.getsize(model_path)
        if file_size == 0:
            raise ValueError(f"Model file is empty: {model_path}")
        
        print(f"📂 Loading model from {model_path}")
        print(f"   File size: {file_size / (1024*1024):.2f} MB")
        
        try:
            model_data = joblib.load(model_path)
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            raise
        
        # 🔥 FIX: Validate model_data is dict
        if model_data is None:
            raise ValueError("Model file loaded but returned None")
        
        if not isinstance(model_data, dict):
            print(f"⚠️ Warning: model_data is {type(model_data)}, expected dict")
            print(f"   Attempting to extract from object...")
            
            if hasattr(model_data, '__dict__'):
                model_data = model_data.__dict__
            else:
                raise TypeError(f"Cannot handle model type: {type(model_data)}")
        
        print(f"✅ Model data loaded: {type(model_data)}")
        print(f"   Keys: {list(model_data.keys())}\n")
        
        # 🔥 FIX: Safe dict access with comprehensive error handling
        try:
            self.user_item_matrix = model_data.get('user_item_matrix')
            self.user_similarity = model_data.get('user_similarity')
            self.item_similarity = model_data.get('item_similarity')
            self.user_encoder = model_data.get('user_encoder')
            self.item_encoder = model_data.get('item_encoder')
            self.popularity_scores = model_data.get('popularity_scores', {})
            self.rental_coordinates = model_data.get('rental_coordinates', {})
            self.user_locations = model_data.get('user_locations', {})
            
            # 🔥 CRITICAL FIX: Validate critical components before calculating stats
            if self.user_item_matrix is None:
                raise ValueError("user_item_matrix is None - cannot proceed")
            
            if not hasattr(self.user_item_matrix, 'shape'):
                raise ValueError(f"user_item_matrix has no shape attribute (type: {type(self.user_item_matrix)})")
            
            if not hasattr(self.user_item_matrix, 'nnz'):
                raise ValueError(f"user_item_matrix has no nnz attribute (type: {type(self.user_item_matrix)})")
            
            if self.user_encoder is None:
                raise ValueError("user_encoder is None")
            
            if self.item_encoder is None:
                raise ValueError("item_encoder is None")
            
            print("✅ All critical components validated")
            
        except KeyError as e:
            print(f"❌ Missing key in model: {e}")
            print(f"   Available keys: {list(model_data.keys())}")
            raise
        
        except AttributeError as e:
            print(f"❌ Attribute error: {e}")
            print(f"   user_item_matrix type: {type(self.user_item_matrix)}")
            if hasattr(self.user_item_matrix, '__dict__'):
                print(f"   Attributes: {dir(self.user_item_matrix)}")
            raise
        
        self.output_dir = './reports'
        os.makedirs(self.output_dir, exist_ok=True)
        
        plt.style.use('seaborn-v0_8-whitegrid')
        sns.set_palette("Set2")
        
        # 🔥 FIX: Calculate statistics with error handling
        try:
            self.stats = self._calculate_stats()
            print(f"✅ Statistics calculated")
            print(f"   Users: {self.stats['n_users']}")
            print(f"   Items: {self.stats['n_items']}")
            print(f"   Sparsity: {self.stats['sparsity']:.2f}%\n")
        except Exception as e:
            print(f"❌ Error calculating statistics: {e}")
            raise
    
    def _calculate_stats(self):
        """Tính toán statistics cần thiết - 🔥 FIXED with comprehensive error handling"""
        try:
            # 🔥 FIX: Validate matrix exists and has required attributes
            if self.user_item_matrix is None:
                print("⚠️ user_item_matrix is None")
                return self._get_default_stats()
            
            if not hasattr(self.user_item_matrix, 'shape'):
                print(f"⚠️ user_item_matrix has no shape (type: {type(self.user_item_matrix)})")
                return self._get_default_stats()
            
            if not hasattr(self.user_item_matrix, 'nnz'):
                print(f"⚠️ user_item_matrix has no nnz (type: {type(self.user_item_matrix)})")
                return self._get_default_stats()
            
            # Extract dimensions
            n_users = self.user_item_matrix.shape[0]
            n_items = self.user_item_matrix.shape[1]
            total_cells = n_users * n_items
            nnz = self.user_item_matrix.nnz
            
            # Calculate sparsity
            sparsity = (1 - nnz / total_cells) * 100 if total_cells > 0 else 100
            density = (nnz / total_cells) * 100 if total_cells > 0 else 0
            
            return {
                'n_users': n_users,
                'n_items': n_items,
                'total_cells': total_cells,
                'nnz': nnz,
                'sparsity': sparsity,
                'density': density,
            }
            
        except AttributeError as e:
            print(f"⚠️ AttributeError in _calculate_stats: {e}")
            return self._get_default_stats()
        
        except Exception as e:
            print(f"⚠️ Unexpected error in _calculate_stats: {e}")
            import traceback
            traceback.print_exc()
            return self._get_default_stats()


    def _get_default_stats(self):
        """Return default stats when calculation fails"""
        return {
            'n_users': 0,
            'n_items': 0,
            'total_cells': 0,
            'nnz': 0,
            'sparsity': 100.0,
            'density': 0.0,
        }
    
    # ==================== BIỂU ĐỒ 1: Ma trận User-Item ====================
    
    def plot_matrix_heatmap(self):
        """📊 Ma trận User-Item - 🔥 FIXED"""
        print("📊 [1/7] Creating User-Item Matrix visualization...")
        
        try:
            # 🔥 FIX: Validate matrix before converting
            if self.user_item_matrix is None:
                print("   ⚠️ user_item_matrix is None, skipping")
                return self.stats
            
            if not hasattr(self.user_item_matrix, 'toarray'):
                print(f"   ⚠️ user_item_matrix cannot be converted to array (type: {type(self.user_item_matrix)})")
                return self.stats
            
            matrix_dense = self.user_item_matrix.toarray()
            
            fig = plt.figure(figsize=(16, 8))
            
            # Main heatmap
            ax = plt.subplot(1, 2, 1)
            im = ax.imshow(matrix_dense, cmap='YlOrRd', aspect='auto')
            
            # Thêm text annotations cho small matrix
            if self.stats['n_users'] <= 20 and self.stats['n_items'] <= 30:
                for i in range(self.stats['n_users']):
                    for j in range(self.stats['n_items']):
                        value = matrix_dense[i, j]
                        if value > 0:
                            text_color = 'white' if value > matrix_dense.max() / 2 else 'black'
                            ax.text(j, i, f'{int(value)}', ha='center', va='center', 
                                   fontsize=7, color=text_color)
            
            ax.set_xlabel('Items (Rentals)', fontsize=12, fontweight='bold')
            ax.set_ylabel('Users', fontsize=12, fontweight='bold')
            ax.set_title('User-Item Interaction Matrix\n(Darker = More interactions)', 
                        fontsize=13, fontweight='bold')
            
            plt.colorbar(im, ax=ax, label='Interaction Score')
            
            # Statistics panel
            ax2 = plt.subplot(1, 2, 2)
            ax2.axis('off')
            
            stats_text = f"""
MATRIX STATISTICS
{'='*40}

👥 Users:                    {self.stats['n_users']}
🏠 Items (Rentals):          {self.stats['n_items']}
📊 Total Cells:              {self.stats['total_cells']:,}

💾 Non-zero Cells:           {self.stats['nnz']}
📉 Sparsity:                 {self.stats['sparsity']:.2f}%
📈 Density:                  {self.stats['density']:.2f}%

INSIGHTS:
{'='*40}
"""
            
            if self.stats['sparsity'] > 90:
                stats_text += "⚠️  Very sparse - more data needed\n"
            elif self.stats['sparsity'] > 70:
                stats_text += "⚡ Moderately sparse - acceptable\n"
            else:
                stats_text += "✅ Good data density\n"
            
            try:
                user_interactions = np.array(self.user_item_matrix.sum(axis=1)).flatten()
                item_interactions = np.array(self.user_item_matrix.sum(axis=0)).flatten()
                
                if user_interactions.mean() > 0 and user_interactions.std() > 0:
                    if user_interactions.std() / user_interactions.mean() > 2:
                        stats_text += "⚠️  Skewed user activity detected\n"
                    else:
                        stats_text += "✅ Balanced user activity\n"
                
                if item_interactions.mean() > 0 and item_interactions.std() > 0:
                    if item_interactions.std() / item_interactions.mean() > 2:
                        stats_text += "⚠️  Skewed item popularity\n"
                    else:
                        stats_text += "✅ Balanced item popularity\n"
            except:
                pass
            
            stats_text += f"""
RECOMMENDATIONS:
{'='*40}
• Collect more interactions
• Ensure diverse user base
• Monitor outliers
"""
            
            ax2.text(0.05, 0.95, stats_text, transform=ax2.transAxes,
                    fontsize=10, verticalalignment='top', fontfamily='monospace',
                    bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '1_user_item_matrix.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
            return self.stats
            
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
            import traceback
            traceback.print_exc()
            return self.stats
    
    # ==================== BIỂU ĐỒ 2: Phân bố điểm tương tác ====================
    
    def plot_interaction_distribution(self):
        """📊 Phân bố score - Chuẩn hơn"""
        print("📊 [2/7] Creating Interaction Distribution...")
        
        try:
            scores = self.user_item_matrix.data
            
            if len(scores) == 0:
                print("   ⚠️ No interaction data\n")
                return
            
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            
            # 1. Histogram
            ax = axes[0, 0]
            counts, bins, patches = ax.hist(scores, bins=30, edgecolor='black', alpha=0.7, color='steelblue')
            
            cm = plt.cm.Blues
            for patch, count in zip(patches, counts):
                patch.set_facecolor(cm(count / max(counts) if counts.max() > 0 else 1))
            
            ax.set_title('Score Distribution (Histogram)', fontsize=12, fontweight='bold')
            ax.set_xlabel('Score Value', fontsize=11)
            ax.set_ylabel('Frequency', fontsize=11)
            ax.grid(axis='y', alpha=0.3)
            
            mean_score = np.mean(scores)
            median_score = np.median(scores)
            ax.axvline(mean_score, color='red', linestyle='--', linewidth=2, label=f'Mean: {mean_score:.2f}')
            ax.axvline(median_score, color='green', linestyle='--', linewidth=2, label=f'Median: {median_score:.2f}')
            ax.legend(fontsize=10)
            
            # 2. Box plot
            ax = axes[0, 1]
            bp = ax.boxplot(scores, vert=True, patch_artist=True, widths=0.5)
            bp['boxes'][0].set_facecolor('lightblue')
            ax.set_title('Score Distribution (Box Plot)', fontsize=12, fontweight='bold')
            ax.set_ylabel('Score Value', fontsize=11)
            ax.grid(axis='y', alpha=0.3)
            
            # 3. Cumulative distribution
            ax = axes[1, 0]
            sorted_scores = np.sort(scores)
            cumulative = np.cumsum(sorted_scores) / np.sum(sorted_scores)
            ax.plot(sorted_scores, cumulative * 100, linewidth=2, color='darkgreen')
            ax.fill_between(sorted_scores, cumulative * 100, alpha=0.3, color='lightgreen')
            ax.set_title('Cumulative Distribution Function', fontsize=12, fontweight='bold')
            ax.set_xlabel('Score Value', fontsize=11)
            ax.set_ylabel('Cumulative %', fontsize=11)
            ax.grid(alpha=0.3)
            
            # 4. Statistics table
            ax = axes[1, 1]
            ax.axis('off')
            
            stats_data = [
                ['Metric', 'Value'],
                ['Count', f'{len(scores)}'],
                ['Mean', f'{np.mean(scores):.2f}'],
                ['Median', f'{np.median(scores):.2f}'],
                ['Std Dev', f'{np.std(scores):.2f}'],
                ['Min', f'{np.min(scores):.2f}'],
                ['Max', f'{np.max(scores):.2f}'],
                ['Q1 (25%)', f'{np.percentile(scores, 25):.2f}'],
                ['Q3 (75%)', f'{np.percentile(scores, 75):.2f}'],
            ]
            
            try:
                skewness = pd.Series(scores).skew()
                stats_data.append(['Skewness', f'{skewness:.2f}'])
            except:
                pass
            
            table = ax.table(cellText=stats_data, cellLoc='center', loc='center',
                            colWidths=[0.4, 0.4])
            table.auto_set_font_size(False)
            table.set_fontsize(10)
            table.scale(1, 2)
            
            for i in range(2):
                table[(0, i)].set_facecolor('#40466e')
                table[(0, i)].set_text_props(weight='bold', color='white')
            
            ax.set_title('Interaction Score Statistics', fontsize=12, fontweight='bold', pad=20)
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '2_interaction_distribution.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    # ==================== BIỂU ĐỒ 3: User Similarity ====================
    
    def plot_user_similarity_heatmap(self):
        """📊 User similarity - Chỉ top 15 users"""
        print("📊 [3/7] Creating User Similarity visualization...")
        
        try:
            if self.user_similarity is None:
                print("   ⚠️ user_similarity is None\n")
                return
            
            if hasattr(self.user_similarity, 'toarray'):
                sim_matrix = self.user_similarity.toarray()
            else:
                sim_matrix = self.user_similarity
            
            max_size = min(15, sim_matrix.shape[0])
            sim_matrix = sim_matrix[:max_size, :max_size]
            
            fig, ax = plt.subplots(figsize=(12, 10))
            
            im = ax.imshow(sim_matrix, cmap='RdBu_r', vmin=-1, vmax=1, aspect='auto')
            
            user_labels = [f'U{i+1}' for i in range(max_size)]
            ax.set_xticks(range(max_size))
            ax.set_yticks(range(max_size))
            ax.set_xticklabels(user_labels, rotation=45)
            ax.set_yticklabels(user_labels)
            
            for i in range(max_size):
                for j in range(max_size):
                    text = ax.text(j, i, f'{sim_matrix[i, j]:.2f}',
                                 ha="center", va="center", color="black", fontsize=8)
            
            ax.set_title('User-User Similarity Matrix\n(Red=Similar, Blue=Different)', 
                        fontsize=13, fontweight='bold')
            
            cbar = plt.colorbar(im, ax=ax, label='Cosine Similarity')
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '3_user_similarity.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    # ==================== BIỂU ĐỒ 4: Popularity ====================
    
    def plot_popularity_chart(self):
        """📊 Top 15 items phổ biến"""
        print("📊 [4/7] Creating Popularity chart...")
        
        try:
            if not self.popularity_scores:
                print("   ⚠️ No popularity data\n")
                return
            
            sorted_items = sorted(
                self.popularity_scores.items(),
                key=lambda x: x[1],
                reverse=True
            )[:15]
            
            rental_labels = [item[0][:8] for item in sorted_items]
            scores = [item[1] for item in sorted_items]
            
            fig, ax = plt.subplots(figsize=(14, 8))
            
            colors = plt.cm.Spectral(np.linspace(0, 1, len(scores)))
            bars = ax.barh(range(len(scores)), scores, color=colors, edgecolor='black', linewidth=1.5)
            
            ax.set_yticks(range(len(scores)))
            ax.set_yticklabels(rental_labels)
            ax.set_xlabel('Popularity Score', fontsize=12, fontweight='bold')
            ax.set_title('Top 15 Most Popular Rentals', fontsize=14, fontweight='bold')
            
            for i, (bar, score) in enumerate(zip(bars, scores)):
                ax.text(score + 1, i, f'{score:.1f}', va='center', fontsize=10, fontweight='bold')
            
            ax.grid(axis='x', alpha=0.3)
            ax.invert_yaxis()
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '4_popularity_ranking.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    # ==================== BIỂU ĐỒ 5: Geographic Distribution ====================
    
    def plot_geographic_distribution(self):
        """🌍 Geographic distribution"""
        print("📊 [5/7] Creating Geographic distribution...")
        
        try:
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(18, 7))
            
            # Rentals
            if self.rental_coordinates:
                valid_coords = {k: v for k, v in self.rental_coordinates.items() 
                              if v[0] != 0 and v[1] != 0}
                
                if valid_coords:
                    rental_lons = [coord[0] for coord in valid_coords.values()]
                    rental_lats = [coord[1] for coord in valid_coords.values()]
                    
                    scatter1 = ax1.scatter(rental_lons, rental_lats, s=200, alpha=0.7, 
                                         c=range(len(rental_lons)), cmap='Reds', 
                                         edgecolors='darkred', linewidth=2)
                    
                    for i, (lon, lat) in enumerate(zip(rental_lons, rental_lats)):
                        ax1.annotate(f'R{i+1}', (lon, lat), fontsize=8, 
                                   xytext=(5, 5), textcoords='offset points')
                    
                    ax1.set_title(f'Rental Locations ({len(valid_coords)} with coordinates)', 
                                fontsize=13, fontweight='bold')
                    ax1.set_xlabel('Longitude', fontsize=11)
                    ax1.set_ylabel('Latitude', fontsize=11)
                    ax1.grid(True, alpha=0.3)
                    plt.colorbar(scatter1, ax=ax1, label='Rental Index')
            
            # Users
            if self.user_locations:
                user_lons = [coord[0] for coord in self.user_locations.values()]
                user_lats = [coord[1] for coord in self.user_locations.values()]
                
                scatter2 = ax2.scatter(user_lons, user_lats, s=250, alpha=0.7,
                                     c=range(len(user_lons)), cmap='Blues',
                                     edgecolors='darkblue', linewidth=2, marker='^')
                
                for i, (lon, lat) in enumerate(zip(user_lons, user_lats)):
                    ax2.annotate(f'U{i+1}', (lon, lat), fontsize=8,
                               xytext=(5, 5), textcoords='offset points')
                
                ax2.set_title(f'User Location Centroids ({len(self.user_locations)} users)', 
                             fontsize=13, fontweight='bold')
                ax2.set_xlabel('Longitude', fontsize=11)
                ax2.set_ylabel('Latitude', fontsize=11)
                ax2.grid(True, alpha=0.3)
                plt.colorbar(scatter2, ax=ax2, label='User Index')
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '5_geographic_distribution.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    # ==================== BIỂU ĐỒ 6: Interactions per User ====================
    
    def plot_interactions_per_user(self):
        """👥 Tương tác mỗi user"""
        print("📊 [6/7] Creating Interactions per User...")
        
        try:
            interactions_count = np.array(self.user_item_matrix.sum(axis=1)).flatten()
            
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            
            # 1. Bar chart
            ax = axes[0, 0]
            users = [f'U{i+1}' for i in range(len(interactions_count))]
            colors = plt.cm.Pastel1(np.linspace(0, 1, len(users)))
            bars = ax.bar(users, interactions_count, color=colors, edgecolor='black', linewidth=1.5)
            
            ax.set_title('Interactions per User (Bar Chart)', fontsize=12, fontweight='bold')
            ax.set_xlabel('User', fontsize=11)
            ax.set_ylabel('Total Score', fontsize=11)
            ax.tick_params(axis='x', rotation=45)
            ax.grid(axis='y', alpha=0.3)
            
            for bar in bars:
                height = bar.get_height()
                if height > 0:
                    ax.text(bar.get_x() + bar.get_width()/2., height,
                           f'{int(height)}', ha='center', va='bottom', fontsize=9)
            
            # 2. Distribution histogram
            ax = axes[0, 1]
            counts, bins, patches = ax.hist(interactions_count, bins=max(10, len(interactions_count)//2), 
                                           edgecolor='black', color='skyblue', alpha=0.7)
            ax.set_title('Distribution of User Activity', fontsize=12, fontweight='bold')
            ax.set_xlabel('Total Score', fontsize=11)
            ax.set_ylabel('Number of Users', fontsize=11)
            ax.grid(axis='y', alpha=0.3)
            
            # 3. Cumulative
            ax = axes[1, 0]
            sorted_interactions = np.sort(interactions_count)[::-1]
            cumsum = np.cumsum(sorted_interactions)
            ax.plot(range(len(sorted_interactions)), cumsum, marker='o', 
                   linewidth=2, markersize=8, color='darkgreen')
            ax.fill_between(range(len(sorted_interactions)), cumsum, alpha=0.3, color='lightgreen')
            ax.set_title('Cumulative Interactions (Pareto)', fontsize=12, fontweight='bold')
            ax.set_xlabel('User Rank', fontsize=11)
            ax.set_ylabel('Cumulative Score', fontsize=11)
            ax.grid(alpha=0.3)
            
            # 4. Statistics
            ax = axes[1, 1]
            ax.axis('off')
            
            stats_data = [
                ['Metric', 'Value'],
                ['Total Users', f'{len(interactions_count)}'],
                ['Average', f'{np.mean(interactions_count):.2f}'],
                ['Median', f'{np.median(interactions_count):.2f}'],
                ['Std Dev', f'{np.std(interactions_count):.2f}'],
                ['Min', f'{np.min(interactions_count):.2f}'],
                ['Max', f'{np.max(interactions_count):.2f}'],
            ]
            
            table = ax.table(cellText=stats_data, cellLoc='center', loc='center',
                            colWidths=[0.4, 0.4])
            table.auto_set_font_size(False)
            table.set_fontsize(10)
            table.scale(1, 2)
            
            for i in range(2):
                table[(0, i)].set_facecolor('#40466e')
                table[(0, i)].set_text_props(weight='bold', color='white')
            
            ax.set_title('User Activity Statistics', fontsize=12, fontweight='bold', pad=20)
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '6_interactions_per_user.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    # ==================== BIỂU ĐỒ 7: Interactions per Item ====================
    
    def plot_interactions_per_item(self):
        """🏠 Tương tác mỗi rental"""
        print("📊 [7/7] Creating Interactions per Item...")
        
        try:
            interactions_count = np.array(self.user_item_matrix.sum(axis=0)).flatten()
            
            fig, axes = plt.subplots(2, 2, figsize=(15, 10))
            
            # Get top 20
            top_indices = np.argsort(interactions_count)[::-1][:20]
            top_counts = interactions_count[top_indices]
            
            # 1. Bar chart (top 20)
            ax = axes[0, 0]
            items = [f'R{i+1}' for i in range(len(top_counts))]
            colors = plt.cm.RdYlGn_r(np.linspace(0.2, 0.8, len(items)))
            bars = ax.barh(range(len(top_counts)), top_counts, color=colors, edgecolor='black', linewidth=1.5)
            
            ax.set_yticks(range(len(top_counts)))
            ax.set_yticklabels(items)
            ax.set_title('Top 20 Rentals by Interactions', fontsize=12, fontweight='bold')
            ax.set_xlabel('Total Score', fontsize=11)
            ax.grid(axis='x', alpha=0.3)
            ax.invert_yaxis()
            
            for i, (bar, val) in enumerate(zip(bars, top_counts)):
                ax.text(val + 10, i, f'{int(val)}', va='center', fontsize=9)
            
            # 2. All items distribution
            ax = axes[0, 1]
            counts, bins, patches = ax.hist(interactions_count, bins=15, edgecolor='black',
                                           color='coral', alpha=0.7)
            ax.set_title('Distribution of Rental Popularity', fontsize=12, fontweight='bold')
            ax.set_xlabel('Total Score', fontsize=11)
            ax.set_ylabel('Number of Rentals', fontsize=11)
            ax.grid(axis='y', alpha=0.3)
            
            # 3. 80-20 rule
            ax = axes[1, 0]
            sorted_scores = np.sort(interactions_count)[::-1]
            cumsum = np.cumsum(sorted_scores)
            cumsum_pct = (cumsum / cumsum[-1]) * 100 if cumsum[-1] > 0 else cumsum * 0
            
            ax.plot(range(len(cumsum_pct)), cumsum_pct, marker='o', linewidth=2.5, 
                   markersize=7, color='darkred', label='Cumulative %')
            ax.axhline(y=80, color='green', linestyle='--', linewidth=2, label='80% threshold')
            ax.fill_between(range(len(cumsum_pct)), cumsum_pct, alpha=0.3, color='lightcoral')
            
            idx_80 = np.where(cumsum_pct >= 80)[0][0] if any(cumsum_pct >= 80) else len(cumsum_pct)
            ax.axvline(x=idx_80, color='orange', linestyle=':', linewidth=2, 
                      label=f'80-20 Point: {idx_80} items')
            
            ax.set_title('Pareto Distribution (80-20 Rule)', fontsize=12, fontweight='bold')
            ax.set_xlabel('Item Rank', fontsize=11)
            ax.set_ylabel('Cumulative %', fontsize=11)
            ax.grid(alpha=0.3)
            ax.legend(fontsize=10)
            ax.set_ylim([0, 105])
            
            # 4. Statistics
            ax = axes[1, 1]
            ax.axis('off')
            
            stats_data = [
                ['Metric', 'Value'],
                ['Total Items', f'{len(interactions_count)}'],
                ['Average', f'{np.mean(interactions_count):.2f}'],
                ['Median', f'{np.median(interactions_count):.2f}'],
                ['Std Dev', f'{np.std(interactions_count):.2f}'],
                ['Min', f'{np.min(interactions_count):.2f}'],
                ['Max', f'{np.max(interactions_count):.2f}'],
            ]
            
            table = ax.table(cellText=stats_data, cellLoc='center', loc='center',
                            colWidths=[0.4, 0.4])
            table.auto_set_font_size(False)
            table.set_fontsize(10)
            table.scale(1, 2)
            
            for i in range(2):
                table[(0, i)].set_facecolor('#40466e')
                table[(0, i)].set_text_props(weight='bold', color='white')
            
            ax.set_title('Item Popularity Statistics', fontsize=12, fontweight='bold', pad=20)
            
            plt.tight_layout()
            output_path = os.path.join(self.output_dir, '7_interactions_per_item.png')
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            print(f"   ✅ Saved: {output_path}\n")
        except Exception as e:
            print(f"   ❌ Error: {e}\n")
    
    def generate_all(self):
        """Generate tất cả visualizations"""
        print("📊 GENERATING ALL VISUALIZATIONS...\n")
        
        self.plot_matrix_heatmap()
        self.plot_interaction_distribution()
        self.plot_user_similarity_heatmap()
        self.plot_popularity_chart()
        self.plot_geographic_distribution()
        self.plot_interactions_per_user()
        self.plot_interactions_per_item()
        
        print("\n" + "="*70)
        print("✅ ALL VISUALIZATIONS GENERATED")
        print("="*70)
        print(f"\n📁 Location: {os.path.abspath(self.output_dir)}/\n")


if __name__ == '__main__':
    try:
        visualizer = ModelVisualizer(model_path='./models/recommendation_model.pkl')
        visualizer.generate_all()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()