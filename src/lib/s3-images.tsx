// S3 Image Helper for Meo Stationery
// This utility helps convert local image paths to S3 URLs
'use client';

import { useState, useEffect } from 'react';
import Image from 'next/image';
import type { ReactElement } from 'react';

const S3_BUCKET_URL = process.env.S3_BUCKET_URL || process.env.NEXT_PUBLIC_S3_BUCKET_URL;

/**
 * Convert local product image path to S3 URL
 */
export function getS3ImageUrl(localPath: string): string {
  if (!S3_BUCKET_URL) {
    console.warn('S3_BUCKET_URL environment variable not set, using local path');
    return localPath;
  }

  // Remove leading slash and "public/" if present
  const cleanPath = localPath.replace(/^\/?(public\/)?/, '');
  
  return `${S3_BUCKET_URL}/${cleanPath}`;
}

/**
 * Get product image URL by product ID and image index
 */
export function getProductImageUrl(productId: string, imageIndex: number): string {
  const localPath = `/products/${productId}/${imageIndex}.jpg`;
  return getS3ImageUrl(localPath);
}

/**
 * Get all image URLs for a product
 */
export function getProductImages(productId: string, maxImages: number = 10): string[] {
  const urls: string[] = [];
  
  for (let i = 0; i < maxImages; i++) {
    urls.push(getProductImageUrl(productId, i));
  }
  
  return urls;
}

/**
 * Preload S3 images for better performance
 */
export function preloadS3Images(imageUrls: string[]): void {
  if (typeof window !== 'undefined') {
    imageUrls.forEach(url => {
      const link = document.createElement('link');
      link.rel = 'preload';
      link.as = 'image';
      link.href = url;
      document.head.appendChild(link);
    });
  }
}

/**
 * React hook to manage S3 image loading state
 */
export function useS3Image(imageUrl: string) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const img = new window.Image();
    
    img.onload = () => {
      setLoading(false);
      setLoaded(true);
      setError(null);
    };
    
    img.onerror = () => {
      setLoading(false);
      setLoaded(false);
      setError('Failed to load image');
    };
    
    img.src = imageUrl;
    
    return () => {
      img.onload = null;
      img.onerror = null;
    };
  }, [imageUrl]);

  return { loading, error, loaded };
}

// Image component with S3 support and fallback
interface S3ImageProps {
  productId: string;
  imageIndex: number;
  alt: string;
  width?: number;
  height?: number;
  className?: string;
  fallbackSrc?: string;
}

export function S3Image({ 
  productId, 
  imageIndex, 
  alt, 
  width = 400, 
  height = 400, 
  className = '',
  fallbackSrc = '/placeholder.jpg'
}: S3ImageProps): ReactElement {
  const [imageSrc, setImageSrc] = useState(getProductImageUrl(productId, imageIndex));
  const [isError, setIsError] = useState(false);

  const handleError = () => {
    if (!isError) {
      setIsError(true);
      setImageSrc(fallbackSrc);
    }
  };

  return (
    <Image
      src={imageSrc}
      alt={alt}
      width={width}
      height={height}
      className={className}
      onError={handleError}
      priority={imageIndex === 0}
    />
  );
}
